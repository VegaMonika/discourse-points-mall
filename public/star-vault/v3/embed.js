import * as T from '../v1/vendor/three/build/three.module.js';
import {GLTFLoader} from '../v1/vendor/three/examples/jsm/loaders/GLTFLoader.js';
import {RoomEnvironment} from '../v1/vendor/three/examples/jsm/environments/RoomEnvironment.js';

const stage=document.getElementById('stage'),loading=document.getElementById('loading');
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
const notify=(type,extra={})=>parent.postMessage({type,...extra},location.origin);
let renderer,model,mixer,clip,action,elapsed=0,playing=false,opened=false,dirty=true,visible=true,disposed=false,openingSent=false;
function fail(){loading.textContent='3D 暂时无法显示，抽奖结果不受影响。';loading.hidden=false;loading.style.display='grid';notify('jn-vault-model-error');}
try{renderer=new T.WebGLRenderer({alpha:false,antialias:true});}catch{fail();}
if(renderer){
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setClearColor(0x202933);
  renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.0;
  renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;stage.appendChild(renderer.domElement);
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(34,1,.1,80);scene.fog=new T.Fog(0x202933,12,32);
  const environment=new RoomEnvironment(),pmrem=new T.PMREMGenerator(renderer),env=pmrem.fromScene(environment,.08);
  scene.environment=env.texture;scene.environmentIntensity=.65;environment.dispose();pmrem.dispose();
  scene.add(new T.HemisphereLight(0xe5edff,0x303036,2.1));
  const light=new T.DirectionalLight(0xffddbf,4);light.position.set(-3,6,5);light.castShadow=true;light.shadow.mapSize.set(1024,1024);light.shadow.camera.left=-4;light.shadow.camera.right=4;light.shadow.camera.top=5;light.shadow.camera.bottom=-3;light.shadow.normalBias=.025;scene.add(light);
  const rim=new T.DirectionalLight(0x91adcb,2.4);rim.position.set(4,3,-4);scene.add(rim);
  const ground=new T.Mesh(new T.PlaneGeometry(160,160),new T.MeshStandardMaterial({color:0x101720,roughness:.97,metalness:.05}));ground.rotation.x=-Math.PI/2;ground.position.y=-.015;ground.receiveShadow=true;scene.add(ground);
  const resize=()=>{const w=Math.max(stage.clientWidth,1),h=Math.max(stage.clientHeight,1);renderer.setSize(w,h,false);camera.aspect=w/h;const d=Math.max(3.4,3.6/camera.aspect)/(2*Math.tan(T.MathUtils.degToRad(17)))*1.36;camera.position.copy(new T.Vector3(4.5,2.8,6.8).normalize().multiplyScalar(d).add(new T.Vector3(0,1.45,0)));camera.lookAt(0,1.45,0);camera.updateProjectionMatrix();dirty=true;};
  const observer=new ResizeObserver(resize);observer.observe(stage);resize();
  const visibility=new IntersectionObserver(([entry])=>{visible=entry.isIntersecting;dirty=true;});visibility.observe(stage);
  function sample(t){if(!mixer)return;action.paused=false;mixer.setTime(t);stage.dataset.animationTime=t.toFixed(2);dirty=true;}
  function open(instant=false){if(!model)return;elapsed=0;openingSent=false;opened=false;sample(0);stage.dataset.phase='unlocking';if(instant||reduced.matches){sample(clip.duration);playing=false;opened=true;stage.dataset.phase='opened';notify('jn-vault-opened');}else{playing=true;}}
  function toggle(){if(!model)return;if(opened){playing=false;opened=false;sample(0);stage.dataset.phase='closed';}else{open();}}
  const message=event=>{if(event.origin!==location.origin||event.source!==parent||event.data?.type!=='jn-vault-visual')return;if(event.data.open)open(!!event.data.instant);else{playing=false;opened=false;sample(0);stage.dataset.phase='closed';}};
  addEventListener('message',message);
  new GLTFLoader().load('industrial-case.glb',g=>{
    if(disposed)return;model=g.scene;model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});scene.add(model);clip=g.animations[0];mixer=new T.AnimationMixer(model);action=mixer.clipAction(clip);action.setLoop(T.LoopOnce,1);action.clampWhenFinished=true;action.play();sample(0);loading.hidden=true;loading.style.display='none';stage.dataset.ready='true';stage.dataset.phase='closed';notify('jn-vault-ready');
  },undefined,fail);
  let drag;
  stage.addEventListener('pointerdown',e=>{if(e.button===0)drag={id:e.pointerId,x:e.clientX,y:e.clientY,rotation:model?.rotation.y||0};});
  stage.addEventListener('pointermove',e=>{if(!drag||e.pointerId!==drag.id||!model)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(Math.abs(dx)>Math.abs(dy)&&Math.abs(dx)>5){stage.setPointerCapture(e.pointerId);model.rotation.y=drag.rotation+dx*.01;dirty=true;}});
  stage.addEventListener('pointerup',e=>{if(drag&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)<5)toggle();drag=null;});
  stage.addEventListener('pointercancel',()=>{drag=null;});
  stage.addEventListener('keydown',e=>{if(['Enter',' '].includes(e.key)){e.preventDefault();toggle();}if(model&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();model.rotation.y+=e.key==='ArrowLeft'?-.2:.2;dirty=true;}});
  const motionChanged=()=>{if(reduced.matches&&playing)open(true);};reduced.addEventListener('change',motionChanged);
  const wake=()=>{dirty=true;};document.addEventListener('visibilitychange',wake);
  let last=0;
  renderer.setAnimationLoop(time=>{const dt=Math.min((time-last)/1000,.08);last=time;if(document.hidden||!visible)return;if(playing){elapsed=Math.min(clip.duration,elapsed+dt);sample(elapsed);if(elapsed>=1.13&&!openingSent){openingSent=true;stage.dataset.phase='opening';notify('jn-vault-opening');}if(elapsed>=clip.duration){playing=false;opened=true;stage.dataset.phase='opened';notify('jn-vault-opened');}}if(dirty){renderer.render(scene,camera);dirty=false;}});
  renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();renderer.setAnimationLoop(null);fail();});
  addEventListener('pagehide',()=>{disposed=true;renderer.setAnimationLoop(null);observer.disconnect();visibility.disconnect();removeEventListener('message',message);reduced.removeEventListener('change',motionChanged);document.removeEventListener('visibilitychange',wake);mixer?.stopAllAction();scene.traverse(o=>{if(o.isMesh){o.geometry.dispose();for(const m of (Array.isArray(o.material)?o.material:[o.material]))m.dispose();}});env.dispose();renderer.dispose();},{once:true});
}
