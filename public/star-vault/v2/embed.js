import * as T from '../v1/vendor/three/build/three.module.js';
import {GLTFLoader} from '../v1/vendor/three/examples/jsm/loaders/GLTFLoader.js';
import {RoomEnvironment} from '../v1/vendor/three/examples/jsm/environments/RoomEnvironment.js';

const stage=document.getElementById('stage'),openButton=document.getElementById('open');
const resetButton=document.getElementById('reset'),loading=document.getElementById('loading');
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let renderer,model,mixer,action,clip,progress=0,target=0,dirty=true,visible=true,disposed=false;
function error(message){loading.textContent=message;loading.style.display='grid';openButton.disabled=true;}
try { renderer=new T.WebGLRenderer({antialias:true,alpha:true}); }
catch { error('当前设备无法显示 3D，商品兑换不受影响。'); }
if(renderer){
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.outputColorSpace=T.SRGBColorSpace;
  renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.18;
  stage.appendChild(renderer.domElement);
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(34,1,.1,60);
  camera.position.set(4.4,3.5,5.8);camera.lookAt(0,1.25,0);
  const environment=new RoomEnvironment(),pmrem=new T.PMREMGenerator(renderer);
  const env=pmrem.fromScene(environment,.04);scene.environment=env.texture;scene.environmentIntensity=.82;
  environment.dispose();pmrem.dispose();
  scene.add(new T.HemisphereLight(0xd1e7ff,0x252139,2.1));
  const key=new T.DirectionalLight(0xf2f1ff,4.5);key.position.set(2,6,5);scene.add(key);
  const rim=new T.DirectionalLight(0x84a9ff,3);rim.position.set(-4,3,-3);scene.add(rim);
  const resize=()=>{const w=Math.max(stage.clientWidth,1),h=Math.max(stage.clientHeight,1);renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();dirty=true;};
  const sizeObserver=new ResizeObserver(resize);sizeObserver.observe(stage);resize();
  const observer=new IntersectionObserver(([e])=>{visible=e.isIntersecting;dirty=true;});observer.observe(stage);
  function disposeModel(root){root.traverse(o=>{if(o.isMesh){o.geometry.dispose();for(const m of (Array.isArray(o.material)?o.material:[o.material]))m.dispose();}});}
  new GLTFLoader().load('../v1/assets/justnainai-star-vault.glb',g=>{
    if(disposed){disposeModel(g.scene);return;}
    model=g.scene;scene.add(model);clip=g.animations[0];mixer=new T.AnimationMixer(model);
    action=mixer.clipAction(clip);action.setLoop(T.LoopOnce,1);action.clampWhenFinished=true;action.play();mixer.setTime(0);
    loading.style.display='none';openButton.disabled=false;stage.dataset.ready='true';dirty=true;
  },undefined,()=>{if(!disposed)error('宝箱加载失败，刷新可重试；商品兑换不受影响。');});
  function toggle(){if(!model)return;target=target?0:1;openButton.setAttribute('aria-pressed',String(!!target));openButton.textContent=target?'合上宝箱':'打开宝箱';dirty=true;}
  openButton.addEventListener('click',toggle);
  addEventListener('message',e=>{if(e.origin===location.origin&&e.source===parent&&e.data?.type==='jn-vault-visual'){target=e.data.open?1:0;dirty=true;}});
  resetButton.addEventListener('click',()=>{if(model)model.rotation.y=0;dirty=true;});
  let drag;
  stage.addEventListener('pointerdown',e=>{if(e.button!==0)return;drag={id:e.pointerId,x:e.clientX,y:e.clientY,rotation:model?.rotation.y||0};});
  stage.addEventListener('pointermove',e=>{if(!drag||drag.id!==e.pointerId||!model)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(Math.abs(dx)>Math.abs(dy)&&Math.abs(dx)>5){stage.setPointerCapture(e.pointerId);model.rotation.y=drag.rotation+dx*.012;dirty=true;}});
  stage.addEventListener('pointerup',e=>{if(drag&&drag.id===e.pointerId&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)<5&&model){const r=stage.getBoundingClientRect(),ray=new T.Raycaster();ray.setFromCamera(new T.Vector2((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1),camera);if(ray.intersectObject(model,true).length)toggle();}drag=null;});
  stage.addEventListener('pointercancel',()=>{drag=null;});
  stage.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();toggle();}else if(['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();if(model)model.rotation.y+=e.key==='ArrowLeft'?-.2:.2;dirty=true;}});
  const invalidate=()=>{dirty=true;};document.addEventListener('visibilitychange',invalidate);reduced.addEventListener('change',invalidate);
  renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();renderer.setAnimationLoop(null);error('3D 显示已暂停，刷新可重试；商品兑换不受影响。');});
  let last=0;
  renderer.setAnimationLoop(time=>{const dt=Math.min((time-last)/1000,.05);last=time;if(document.hidden||!visible)return;if(Math.abs(progress-target)>.0001&&mixer){progress=reduced.matches?target:T.MathUtils.damp(progress,target,5,dt);if(Math.abs(progress-target)<.001)progress=target;action.paused=false;mixer.setTime(progress*clip.duration);dirty=true;}if(dirty){renderer.render(scene,camera);dirty=false;}});
  addEventListener('pagehide',()=>{disposed=true;renderer.setAnimationLoop(null);observer.disconnect();sizeObserver.disconnect();document.removeEventListener('visibilitychange',invalidate);reduced.removeEventListener('change',invalidate);mixer?.stopAllAction();if(model){mixer?.uncacheRoot(model);disposeModel(model);}env.dispose();renderer.dispose();},{once:true});
}
