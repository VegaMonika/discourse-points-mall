import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { registerDestructor } from "@ember/destroyable";
import { modifier } from "ember-modifier";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { fn } from "@ember/helper";
import { makeReel, reelFrames, reelGeometry, reelProgress, REEL_DURATION, WINNING_INDEX } from "../lib/star-vault-reel";

const viewerURL = getURL("/plugins/discourse-points-mall/star-vault/v3/embed.html");

export default class PointsMallStarVault extends Component {
  @tracked state = null;
  @tracked busy = false;
  @tracked error = "";
  @tracked modalOpen = false;
  @tracked spinning = false;
  @tracked demo = false;
  @tracked result = null;
  @tracked cards = [];
  @tracked sound = true;
  @tracked audioState = "idle";
  @tracked phase = "closed";
  voices = new Set();
  winningIndex = WINNING_INDEX;

  constructor() {
    super(...arguments);
    window.addEventListener("message", this.sceneMessage);
    this.loadStatus();
    registerDestructor(this, () => {
      this.dead = true;
      window.removeEventListener("message", this.sceneMessage);
      this.stopAnimation();
      this.stopSound();
      this.audio?.close();
    });
  }

  get disabled() { return this.busy || !this.state?.available; }
  get previewDisabled() { return this.busy || !this.state?.pool?.length; }
  get phaseLabel() {
    return { loading: "正在准备补给箱…", unlocking: "钥匙解锁中…", opening: "正在打开箱盖…", rolling: "奖品正在落定…" }[this.phase] || "奖品正在落定…";
  }
  get audioHint() {
    if (!this.sound) { return "已静音"; }
    if (this.audioState === "unavailable") { return "设备暂不支持音效"; }
    if (this.audioState === "suspended") { return "声音已暂停，请点击音效按钮重新开启"; }
    return this.audioState === "running" ? "音效已就绪 · 无声时请检查设备静音" : "点击开箱时启用音效";
  }
  get isCosmetic() { return this.result?.kind === "cosmetic"; }
  get isGame() { return this.result?.kind === "game"; }
  get delivered() { return this.result?.delivery_state === "completed"; }
  get waitingAccount() { return this.result?.delivery_state === "waiting_account"; }
  get deliveryLabel() {
    if (this.delivered) { return this.isCosmetic ? "已放入背包" : "奖励已到账"; }
    return this.result?.delivery_state === "needs_review" ? "已中奖 · 到账待核对" : "已中奖 · 等待发放";
  }

  get openLabel() {
    if (this.busy) { return "正在确认奖励…"; }
    if (!this.state) { return "正在读取次数…"; }
    if (this.state.today) { return "今日已领取"; }
    return this.state.enabled ? "每日免费开箱" : "活动暂未开放";
  }

  get expiryLabel() {
    return this.result?.expires_at ? new Date(this.result.expires_at).toLocaleString("zh-CN", { timeZone: "Asia/Shanghai", hour12: false }) : "";
  }

  @action
  async loadStatus() {
    try {
      const state = await ajax("/points-mall/star-vault.json");
      if (!this.dead) {
        this.state = state; this.error = state.error || "";
        if (!this.demo && this.result?.draw_id) {
          this.result = state.recent.find(item => item.draw_id === this.result.draw_id) || this.result;
        }
      }
    } catch {
      if (!this.dead) { this.error = "暂时无法读取宝箱，请重试。"; }
    }
  }

  @action
  async open() {
    if (this.disabled) { return; }
    this.busy = true; this.error = "";
    this.prepareAudio();
    try {
      const data = await ajax("/points-mall/star-vault/open.json", { type: "POST" });
      if (this.dead) { return; }
      this.state = { ...this.state, available: false, today: data.result };
      this.showRoll(data.result, false, data.created);
    } catch {
      if (!this.dead) {
        await this.loadStatus();
        this.error = this.state?.today ? "抽取结果已保存，可查看今日奖励及到账状态。" : "请求未确认，请刷新次数后重试；同日重试不会重复领取。";
      }
    } finally {
      if (!this.dead) { this.busy = false; }
    }
  }

  @action
  preview() {
    if (!this.state?.pool?.length || this.busy) { return; }
    this.prepareAudio();
    const pool = this.state.pool;
    this.showRoll(pool[Math.floor(Math.random() * pool.length)], true, true);
  }

  @action
  viewToday() {
    if (this.state?.today) { this.showRoll(this.state.today, false, false); }
  }

  @action
  viewRecent(reward) { this.showRoll(reward, false, false); }

  @action
  async retryDelivery() {
    if (!this.waitingAccount || this.busy) { return; }
    this.busy = true;
    try {
      const response = await ajax(`/points-mall/star-vault/${this.result.draw_id}/retry.json`, { type: "POST" });
      if (!this.dead) { this.result = response.result; }
    } catch { if (!this.dead) { this.error = "补领请求未确认，请刷新奖励状态。"; } }
    finally { if (!this.dead) { this.busy = false; } }
  }

  showRoll(winner, demo, animate) {
    this.track = null; this.geometry = null;
    this.result = winner; this.demo = demo;
    this.cards = makeReel(this.state.pool, winner);
    this.spinning = animate; this.modalOpen = true;
    this.phase = animate ? "loading" : "settled";
  }

  rememberFrame = modifier((element) => {
    this.frame = element;
    return () => { this.frame = null; };
  });

  rememberScene = modifier((element) => {
    this.sceneFrame = element;
    return () => { this.sceneFrame = null; };
  });

  @action
  sceneMessage(event) {
    if (!this.modalOpen || event.origin !== location.origin || event.source !== this.sceneFrame?.contentWindow) { return; }
    if (event.data?.type === "jn-vault-ready") {
      if (!this.spinning) { this.sceneFrame.contentWindow.postMessage({ type: "jn-vault-visual", open: true, instant: true }, location.origin); return; }
      if (this.phase !== "loading") { return; }
      clearTimeout(this.sceneTimer);
      this.phase = "unlocking";
      this.sceneFrame.contentWindow.postMessage({ type: "jn-vault-visual", open: true }, location.origin);
      this.tone(220, 0.10, 0.55, 0.055);
      this.sceneTimer = setTimeout(() => this.beginReel(), 3800);
    } else if (event.data?.type === "jn-vault-opening" && this.phase === "unlocking") {
      this.phase = "opening"; this.tone(310, 0.08, 0, 0.055);
    } else if (event.data?.type === "jn-vault-opened" || event.data?.type === "jn-vault-model-error") {
      this.beginReel();
    }
  }

  beginReel() {
    if (this.dead || !this.modalOpen || !this.spinning || this.phase === "rolling") { return; }
    clearTimeout(this.sceneTimer);
    this.phase = "rolling";
    this.animate(this.dialog?.querySelector(".jn-vault-reel-track"));
  }

  mountDialog = modifier((element) => {
    this.returnFocus = document.activeElement;
    element.showModal(); this.dialog = element;
    this.frameRequest = requestAnimationFrame(() => {
      if (!this.spinning) { this.animate(element.querySelector(".jn-vault-reel-track")); }
      else if (this.phase === "loading") { this.sceneTimer = setTimeout(() => this.beginReel(), 5000); }
    });
    return () => {
      this.stopAnimation(); this.resizeObserver?.disconnect();
      element.close(); this.dialog = null;
    };
  });

  setupTrack(track) {
    if (!track) { return; }
    this.track = track; this.landing = (Math.random() - 0.5) * 24;
    const geometry = () => reelGeometry(track.parentElement.clientWidth, track.firstElementChild.getBoundingClientRect().width, parseFloat(getComputedStyle(track).gap) || 0, this.landing);
    this.geometry = geometry;
    track.dataset.ready = "true";
  }

  animate(track) {
    if (!track || this.dead) { return; }
    this.setupTrack(track);
    const geometry = this.geometry;
    const { start, end, step } = geometry();
    track.style.transform = `translate3d(${start}px,0,0)`;
    track.dataset.ready = "true";
    const reduced = matchMedia("(prefers-reduced-motion: reduce)");
    const size = track.parentElement.clientWidth;
    this.resizeObserver = new ResizeObserver(() => {
      if (track.parentElement.clientWidth !== size) { this.finish(); }
    });
    this.resizeObserver.observe(track.parentElement);
    this.motionQuery = reduced;
    this.motionChanged = () => { if (reduced.matches) { this.finish(); } };
    reduced.addEventListener("change", this.motionChanged);
    if (!this.spinning || reduced.matches) { this.finish(); return; }
    this.animation = track.animate(reelFrames(start, end), { duration: REEL_DURATION, easing: "linear", fill: "forwards" });
    this.animation.finished.then(() => this.finish()).catch(() => {});
    let lastSlot = -1;
    const tick = () => {
      if (!this.animation || this.dead || !this.spinning) { return; }
      const progress = reelProgress(Number(this.animation.currentTime || 0) / REEL_DURATION);
      const slot = Math.floor(Math.abs((end - start) * progress) / step);
      if (slot !== lastSlot && !document.hidden) { this.tone(1250, 0.035, 0, 0.075); lastSlot = slot; }
      this.soundRequest = requestAnimationFrame(tick);
    };
    tick();
  }

  stopAnimation() {
    clearTimeout(this.sceneTimer);
    cancelAnimationFrame(this.frameRequest); cancelAnimationFrame(this.soundRequest);
    this.animation?.cancel(); this.animation = null;
    this.motionQuery?.removeEventListener("change", this.motionChanged);
  }

  @action
  finish() {
    const wasSpinning = this.spinning;
    this.stopAnimation();
    if (!this.track) { this.setupTrack(this.dialog?.querySelector(".jn-vault-reel-track")); }
    if (this.track && this.geometry) { this.track.style.transform = `translate3d(${this.geometry().end}px,0,0)`; }
    this.spinning = false;
    this.phase = "settled";
    this.sceneFrame?.contentWindow?.postMessage({ type: "jn-vault-visual", open: true, instant: true }, location.origin);
    if (wasSpinning) {
      this.tone(392, 0.16, 0, 0.085);
      this.tone(587.33, 0.22, 0.07, 0.075);
      this.tone(783.99, 0.36, 0.14, 0.065);
    }
    if (wasSpinning && !this.demo) { this.loadStatus(); }
  }

  @action
  close(event) {
    event?.preventDefault();
    this.dialog?.close();
    this.stopSound();
    this.stopAnimation(); this.modalOpen = false; this.spinning = false;
    if (this.returnFocus?.isConnected) { this.returnFocus.focus({ preventScroll: true }); }
  }

  @action
  inventory() { this.close(); this.args.onInventory?.(); }

  @action
  toggleSound() {
    if (this.sound && this.audioState === "suspended") { this.prepareAudio(); return; }
    this.sound = !this.sound;
    if (this.sound) { this.prepareAudio(); }
    else { this.stopSound(); }
  }

  stopSound() {
    this.voices.forEach(voice => { try { voice.stop(); } catch { /* Already ended. */ } });
    this.voices.clear();
  }

  prepareAudio() {
    if (!this.sound) { return; }
    try {
      this.audio ||= new (window.AudioContext || window.webkitAudioContext)();
      this.audio.onstatechange = () => { if (!this.dead) { this.audioState = this.audio.state; } };
      this.audioState = this.audio.state;
      this.audio.resume().then(() => {
        if (!this.dead) { this.audioState = this.audio.state; this.tone(520, 0.08, 0, 0.06); }
      }).catch(() => { if (!this.dead) { this.audioState = "suspended"; } });
    } catch { this.audioState = "unavailable"; }
  }

  tone(frequency, duration, delay = 0, volume = 0.075) {
    if (!this.sound || !this.audio || this.audio.state !== "running") { return; }
    const oscillator = this.audio.createOscillator(), gain = this.audio.createGain(), now = this.audio.currentTime + delay;
    oscillator.type = "triangle";
    oscillator.frequency.value = frequency;
    gain.gain.setValueAtTime(0.001, now); gain.gain.linearRampToValueAtTime(volume, now + 0.003); gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    oscillator.connect(gain); gain.connect(this.audio.destination);
    this.voices.add(oscillator);
    oscillator.onended = () => { this.voices.delete(oscillator); oscillator.disconnect(); gain.disconnect(); };
    oscillator.start(now); oscillator.stop(now + duration);
  }

  <template>
    <div class="points-mall-star-vault points-mall-star-vault--daily">
      <iframe src={{viewerURL}} title="星辉宝库 3D 外观，可拖动旋转" loading="lazy" referrerpolicy="same-origin" width="320" height="250" {{this.rememberFrame}}></iframe>
      <button class="jn-vault-open" type="button" disabled={{this.disabled}} {{on "click" this.open}}>{{this.openLabel}}</button>
      <div class="jn-vault-small-actions">
        <button type="button" disabled={{this.previewDisabled}} {{on "click" this.preview}}>试开动画</button>
        <button type="button" aria-pressed={{this.sound}} {{on "click" this.toggleSound}}>音效：{{if this.sound "开" "关"}}</button>
        {{#if this.state.today}}<button type="button" {{on "click" this.viewToday}}>今日奖励</button>{{/if}}
      </div>
      <p class="jn-vault-rule">每天免费 1 次 · 北京时间 00:00 重置</p>
      {{#if this.error}}<p class="jn-vault-error" role="status">{{this.error}} <button type="button" {{on "click" this.loadStatus}}>刷新次数</button></p>{{/if}}
      <details class="jn-vault-pool">
        <summary>奖池与公开概率</summary>
        <p>装扮 80% · 游戏道具 18% · 云盘流量 2%。不消耗积分，奖品不可交易、提现。装扮从领取时计时，不覆盖当前装备；游戏道具需先进入游戏创建存档。</p>
        {{#each this.state.pool key="key" as |prize|}}<div class="jn-vault-pool-item rarity-{{prize.rarity}}"><span>{{prize.name}}</span><strong>{{prize.probability}}%</strong></div>{{/each}}
      </details>
      {{#if this.state.recent.length}}<details class="jn-vault-pool"><summary>最近奖励与补领</summary>{{#each this.state.recent key="draw_id" as |reward|}}<button class="jn-vault-history-item" type="button" {{on "click" (fn this.viewRecent reward)}}>{{reward.draw_on}} · {{reward.name}} →</button>{{/each}}</details>{{/if}}
    </div>
    {{#if this.modalOpen}}
      <dialog class="jn-vault-dialog jn-vault-dialog--scene jn-vault-dialog--case phase-{{this.phase}} {{if this.spinning 'is-spinning' 'is-settled'}}" data-audio-state={{this.audioState}} data-phase={{this.phase}} aria-labelledby="jn-vault-dialog-title" {{this.mountDialog}} {{on "cancel" this.close}}>
        <header><div><span class="jn-vault-eyebrow">{{if this.demo "演示模式 · 不消耗次数，不发放奖励" "每日免费活动箱 · 奖励已由服务器保存"}}</span><h2 id="jn-vault-dialog-title">星辉宝库</h2></div><button type="button" class="jn-vault-close" aria-label="关闭开箱窗口" {{on "click" this.close}}>×</button></header>
        <div class="jn-vault-scene">
        <div class="jn-vault-scene-backdrop" aria-hidden="true" inert><iframe src={{viewerURL}} title="钥匙解锁与空箱开盖场景" tabindex="-1" width="960" height="500" {{this.rememberScene}}></iframe></div>
        <span class="jn-vault-scene-caption" aria-hidden="true">STAR VAULT / DAILY DROP</span>
        <div class="jn-vault-reel" aria-hidden="true"><div class="jn-vault-pointer"></div><div class="jn-vault-reel-track">{{#each this.cards key="slot" as |item|}}<div class="jn-vault-prize rarity-{{item.rarity}} {{if (eq item.slot this.winningIndex) 'is-winning-slot'}}"><img src={{item.image_url}} alt="" /><small>{{item.tier}}</small><strong>{{item.name}}</strong></div>{{/each}}</div></div>
        </div>
        <div class="jn-vault-sound-controls"><button type="button" aria-pressed={{this.sound}} {{on "click" this.toggleSound}}>音效：{{if this.sound "开" "关"}}</button><small role="status">{{this.audioHint}}</small></div>
        {{#if this.spinning}}
          <div class="jn-vault-wait" role="status">{{this.phaseLabel}}</div>
          <button type="button" class="jn-vault-skip" {{on "click" this.finish}}>跳过动画</button>
        {{else}}
          <section class="jn-vault-result rarity-{{this.result.rarity}}" role="status"><small>{{if this.demo "本次演示结果" this.deliveryLabel}}</small><h3>{{this.result.name}}</h3>{{#unless this.demo}}{{#if this.isCosmetic}}<p>有效期至 {{this.expiryLabel}}（北京时间）</p>{{else}}<p>{{this.result.delivery_error}}</p><p>订单号：{{this.result.order_id}}</p>{{/if}}{{/unless}}</section>
          <div class="jn-vault-result-actions">{{#unless this.demo}}{{#if this.isCosmetic}}<button type="button" class="jn-vault-open" {{on "click" this.inventory}}>去背包装备</button>{{else}}{{#if this.isGame}}<a href="https://game.justnainai.com/" target="_blank" rel="noopener noreferrer">进入游戏</a>{{else}}<a href="https://pan.justnainai.com/" target="_blank" rel="noopener noreferrer">查看云盘流量</a>{{/if}}{{#if this.waitingAccount}}<button type="button" disabled={{this.busy}} {{on "click" this.retryDelivery}}>已创建存档，补领</button>{{/if}}<button type="button" {{on "click" this.loadStatus}}>刷新到账状态</button>{{/if}}{{/unless}}<button type="button" {{on "click" this.close}}>完成</button></div>
        {{/if}}
        <p class="jn-vault-disclaimer">{{if this.demo "试开只预览动画，不代表实际中奖概率。实际概率见商店奖池。" "关闭、跳过或刷新不会改变奖励；今日结果可随时查看。"}}</p>
      </dialog>
    {{/if}}
  </template>
}
