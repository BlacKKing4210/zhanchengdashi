/* PNG proposals only. No engine, account, config or gameplay writes. */
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const K=require('../native_components/common.cjs');
const BASE=path.resolve(__dirname,'..'),C=K.C;
const read=p=>JSON.parse(fs.readFileSync(path.join(BASE,p),'utf8'));
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
const DATA=read('core_pages/native-scene-data.json'),G=DATA.geometry;
const sourceArt=read('core_pages/native-art-sources.json'),formal=Object.fromEntries(sourceArt.assets.map(x=>[x.id,x]));
 const controls=[],outputs=[],portraits={};let poster,posterFeathered,arena,mouse,mouseBox;
const record=(page,id,rect,meaning)=>controls.push({page,id,rect,meaning});
function crop(image,box){const [x,y,r,b]=box,c=K.createCanvas(r-x,b-y);c.getContext('2d').drawImage(image,x,y,r-x,b-y,0,0,r-x,b-y);return c;}
function put(ctx,id,rect,factor=1){const im=portraits[id],s=Math.min(rect[2]/im.width,rect[3]/im.height)*factor;ctx.drawImage(im,rect[0]+(rect[2]-im.width*s)/2,rect[1]+(rect[3]-im.height*s)/2,im.width*s,im.height*s);}
function backdrop(ctx){K.image(ctx,arena,0,0,720,1280);const v=ctx.createLinearGradient(0,0,0,1280);v.addColorStop(0,'rgba(5,35,37,.28)');v.addColorStop(.3,'rgba(5,38,41,.13)');v.addColorStop(.72,'rgba(6,36,39,.32)');v.addColorStop(1,'rgba(4,24,31,.75)');ctx.fillStyle=v;ctx.fillRect(0,0,720,1280);}
function header(ctx,page,tickets){K.currency(ctx,...G.currency_left,60,'coin');K.currency(ctx,...G.currency_right,tickets,'ticket');K.text(ctx,'抽卡',...G.title,44,{align:'center',color:'#fff7da',outline:5});record(page,'gold',G.currency_left,'60');record(page,'ticket',G.currency_right,String(tickets));record(page,'title',G.title,'抽卡');}
function recentButton(ctx,page){const r=[508,142,184,54];K.button(ctx,...r,'最近获得',{kind:'secondary',size:25});record(page,'recent_history',r,'Open recent-record preview');}
function cost(ctx,x,value){K.icon(ctx,'ticket',x,1000,38,38);K.text(ctx,'×'+value,x+45,1001,84,36,24,{color:'#fff',outline:3});}
function actions(ctx,page,{enabled=true,busy=false}={}){
 const shade=ctx.createLinearGradient(0,954,0,1145);shade.addColorStop(0,'rgba(7,32,34,0)');shade.addColorStop(.25,'rgba(9,36,38,.8)');shade.addColorStop(1,'rgba(9,29,37,.98)');ctx.fillStyle=shade;ctx.fillRect(0,954,720,194);
 if(!busy){cost(ctx,184,1);cost(ctx,457,10);}
 K.button(ctx,...G.one_cta,'抽1次',{enabled:enabled&&!busy,size:28});K.button(ctx,...G.ten_cta,'抽10次',{enabled:enabled&&!busy,kind:'gold',size:28});K.nav(ctx,'gacha');
 record(page,'one',G.one_cta,enabled&&!busy?'Enabled;cost1':'Disabled');record(page,'ten',G.ten_cta,enabled&&!busy?'Enabled;cost10':'Disabled');G.nav_slots.forEach((r,i)=>record(page,'nav_'+i,r,'Current five routes, gacha active'));
}
function sparkle(ctx,x,y,size){
 const gl=ctx.createRadialGradient(x,y,0,x,y,size*2.8);gl.addColorStop(0,'rgba(255,246,184,.6)');gl.addColorStop(1,'rgba(255,231,130,0)');ctx.fillStyle=gl;ctx.fillRect(x-size*3,y-size*3,size*6,size*6);
 ctx.beginPath();ctx.moveTo(x,y-size);ctx.quadraticCurveTo(x+size*.18,y-size*.18,x+size,y);ctx.quadraticCurveTo(x+size*.18,y+size*.18,x,y+size);ctx.quadraticCurveTo(x-size*.18,y+size*.18,x-size,y);ctx.quadraticCurveTo(x-size*.18,y-size*.18,x,y-size);ctx.fillStyle='#fff5be';ctx.fill();
}
function revealLight(ctx,cx,cy,r,kind='hero'){
 // Continuous warm central bloom, eight finite tapered beams and five small accents.
 // All light is painted BEFORE the untouched character/card and fixed UI.
 ctx.save();const g=ctx.createRadialGradient(cx,cy,20,cx,cy,r);
 g.addColorStop(0,'rgba(255,251,218,.98)');g.addColorStop(.26,'rgba(255,236,156,.84)');g.addColorStop(.52,'rgba(236,236,152,.52)');g.addColorStop(.76,'rgba(181,221,140,.22)');g.addColorStop(1,'rgba(137,196,113,0)');
 ctx.fillStyle=g;ctx.fillRect(cx-r,cy-r,r*2,r*2);
 const angles=[-2.7,-2.12,-1.53,-.88,-.25,.45,1.1,2.32],lengths=[.86,.98,1,.86,.92,.8,.77,.94];
 angles.forEach((a,i)=>{const length=r*lengths[i],wide=.08+(i%3)*.022,inner=36;const p0=[cx+Math.cos(a-wide)*inner,cy+Math.sin(a-wide)*inner],p1=[cx+Math.cos(a-wide)*length,cy+Math.sin(a-wide)*length],p2=[cx+Math.cos(a+wide)*length,cy+Math.sin(a+wide)*length];ctx.beginPath();ctx.moveTo(...p0);ctx.lineTo(...p1);ctx.lineTo(...p2);ctx.closePath();const ray=ctx.createLinearGradient(cx,cy,cx+Math.cos(a)*length,cy+Math.sin(a)*length);ray.addColorStop(0,'rgba(255,251,219,.48)');ray.addColorStop(.54,'rgba(255,242,177,.2)');ray.addColorStop(1,'rgba(255,248,206,0)');ctx.fillStyle=ray;ctx.fill();});
 if(kind==='opening'){
  ctx.save();ctx.translate(cx,cy+158);ctx.scale(1,.27);const rg=ctx.createRadialGradient(0,0,95,0,0,180);rg.addColorStop(0,'rgba(255,234,122,0)');rg.addColorStop(.65,'rgba(255,233,134,.1)');rg.addColorStop(.8,'rgba(255,241,170,.8)');rg.addColorStop(.88,'rgba(255,241,170,.2)');rg.addColorStop(1,'rgba(255,234,122,0)');ctx.fillStyle=rg;ctx.beginPath();ctx.arc(0,0,180,0,Math.PI*2);ctx.fill();ctx.restore();
 }
 const points=kind==='hero'?[[132,344,11],[578,421,9],[491,245,7],[132,695,8],[568,748,12]]:[[149,418,9],[570,448,11],[185,810,9],[541,797,8],[487,365,7]];
 points.forEach(p=>sparkle(ctx,...p));ctx.restore();
}
function mainScreen(page,tickets=30){
 const {canvas,ctx}=K.createPage();
 // A quiet green field beneath the poster feather prevents two forest scenes/logs
 // becoming visible together in the header transition.
 const ground=ctx.createLinearGradient(0,0,0,1280);ground.addColorStop(0,'#124b43');ground.addColorStop(.24,'#31674d');ground.addColorStop(.65,'#365c3f');ground.addColorStop(1,'#0b2632');ctx.fillStyle=ground;ctx.fillRect(0,0,720,1280);
 // Exact3:4 illustration fitted once; important animal faces are never cropped.
 ctx.drawImage(posterFeathered,0,126,720,960);
 header(ctx,page,tickets);recentButton(ctx,page);
 K.text(ctx,'伙伴集结',40,238,640,78,65,{align:'center',color:'#fff7cf',outline:7});K.text(ctx,'和伙伴一起出发',60,316,600,42,25,{align:'center',color:'#fff9e5',outline:4});
 actions(ctx,page,{enabled:tickets>=10});
 if(!tickets){K.text(ctx,'抽卡券不足',220,958,280,32,22,{align:'center',color:'#fff8df',outline:3});record(page,'insufficient_state',[220,958,280,32],'0tickets; both CTA disabled');}
 return{canvas,ctx};
}
function save(page,canvas,state,extra={}){const f=path.join(__dirname,page+'.png');K.save(canvas,f);outputs.push({id:page,file:page+'.png',sha256:sha(f),size:[720,1280],state,render_method:'AI_ILLUSTRATION_AND_USER_AUTHORIZED_NATIVE_UI',runtime_approved:false,...extra});}
function opening(){
 const page='07_gacha_opening',state=DATA.states[1],{canvas,ctx}=K.createPage();backdrop(ctx);K.dim(ctx,.21);header(ctx,page,state.tickets);
 K.text(ctx,'伙伴即将登场',62,265,596,60,35,{align:'center',color:'#fff5c9',outline:4});
 revealLight(ctx,360,618,402,'opening');
 const [x,y,w,h]=G.single_card;
 ctx.save();ctx.shadowColor='rgba(0,18,32,.45)';ctx.shadowBlur=22;ctx.shadowOffsetY=16;K.panel(ctx,x,y,w,h,{fill:'#304f76',stroke:C.ink,line:6,radius:18});ctx.restore();
 const cg=ctx.createLinearGradient(x,y,x+w,y+h);cg.addColorStop(0,'#455d92');cg.addColorStop(.5,'#273f71');cg.addColorStop(1,'#405683');K.panel(ctx,x+12,y+12,w-24,h-24,{fill:cg,stroke:'#f5d976',line:3,radius:12});
 K.panel(ctx,x+25,y+25,w-50,h-50,{fill:'rgba(30,44,81,.2)',stroke:'#a3b8d7',line:1.5,radius:9});K.icon(ctx,'star',x+w/2-53,y+h/2-53,106,106);
 for(const [a,b,sx,sy] of [[x+28,y+28,1,1],[x+w-28,y+28,-1,1],[x+28,y+h-28,1,-1],[x+w-28,y+h-28,-1,-1]]){ctx.beginPath();ctx.moveTo(a+sx*22,b);ctx.lineTo(a,b);ctx.lineTo(a,b+sy*22);ctx.strokeStyle='#f5d976';ctx.lineWidth=3;ctx.stroke();}
 actions(ctx,page,{busy:true});
 K.panel(ctx,130,966,460,62,{fill:C.navy,line:3,radius:12});K.text(ctx,state.toast,130,966,460,62,24,{align:'center',color:'#fff'});record(page,'toast',[130,966,460,62],state.toast);record(page,'card_back',G.single_card,'Unrevealed generic star back; no animal or rarity shown');
 save(page,canvas,{...state,record_entry:'Recent records moved to secondary entry on promotional main'}, {light:{kind:'central_bloom_finite_beams_energy_orbit',behind_card:true,beam_count:8,sparks:5},source_card_rect:G.single_card});
}
function hero(){
 const page='09_gacha_new_hero',state=DATA.states[3],{canvas,ctx}=K.createPage();backdrop(ctx);
 // Dark broad scene values keep the warm reveal light intentional and readable.
 K.dim(ctx,.14);revealLight(ctx,360,535,419,'hero');
 const platform=ctx.createRadialGradient(360,793,8,360,793,220);platform.addColorStop(0,'rgba(255,250,187,.6)');platform.addColorStop(1,'rgba(255,242,161,0)');ctx.save();ctx.translate(0,790);ctx.scale(1,.14);ctx.fillStyle=platform;ctx.fillRect(100,-10,520,180);ctx.restore();
 const [x,y,w,h]=G.hero_portrait,s=Math.min(w/mouse.width,h/mouse.height);ctx.drawImage(mouse,x+(w-mouse.width*s)/2,y+(h-mouse.height*s)/2,mouse.width*s,mouse.height*s);
 K.text(ctx,state.name,...G.hero_name,46,{align:'center',color:'#fff6d8',outline:5});
 K.panel(ctx,...G.hero_slogan,{fill:'#fff9e8',stroke:C.ink,line:3,radius:22});ctx.beginPath();ctx.moveTo(344,937);ctx.lineTo(360,919);ctx.lineTo(378,937);ctx.fillStyle='#fff9e8';ctx.fill();ctx.strokeStyle=C.ink;ctx.lineWidth=3;ctx.stroke();K.text(ctx,state.slogan,90,977,540,38,30,{align:'center'});K.button(ctx,...G.hero_continue,'继续',{size:34});
 record(page,'portrait',G.hero_portrait,'Same high-resolution mouse, exact current portrait rect and pose');record(page,'name',G.hero_name,state.name);record(page,'slogan',G.hero_slogan,state.slogan);record(page,'continue',G.hero_continue,'Continue');
 save(page,canvas,state,{light:{kind:'warm_central_bloom_finite_tapered_beams',behind_untouched_alpha_mouse:true,beam_count:8,sparks:5,not_drawn_over_UI:true},portrait_source:{file:'../native_components/illustrations/gray-mouse-hero.png',sha256:sha(path.join(BASE,'native_components/illustrations/gray-mouse-hero.png')),alpha_bbox:mouseBox,rect:G.hero_portrait,fit_scale:s}});
}
function history(){
 const page='10_recent_history',state=DATA.states[2],{canvas,ctx}=mainScreen(page,30);K.dim(ctx,.55);K.panel(ctx,46,214,628,824,{fill:C.cream,line:4,radius:22});
 K.clip(ctx,46,214,628,104,()=>K.panel(ctx,46,214,628,104,{fill:C.navy,line:0,radius:22}));K.text(ctx,'最近获得',88,240,544,54,36,{align:'center',color:'#fff6db'});
 K.panel(ctx,601,242,48,48,{fill:'#eff4e7',line:2,radius:12});ctx.beginPath();ctx.moveTo(616,257);ctx.lineTo(634,275);ctx.moveTo(634,257);ctx.lineTo(616,275);ctx.strokeStyle=C.ink;ctx.lineWidth=3.5;ctx.stroke();record(page,'close',[601,242,48,48],'Return to promotional main');
 const cards=[];state.card_ids.forEach((id,i)=>{const card=formal[id],x=88+(i%2)*280,y=336+Math.floor(i/2)*124,w=264,h=108;const fill=card.rarity==='rare'?'#a8dff4':'#c1dc9a';K.panel(ctx,x,y,w,h,{fill,line:2.5,radius:13});put(ctx,id,[x+10,y+10,88,84]);K.text(ctx,card.name,x+111,y+31,w-122,42,25);cards.push({id,name:card.name,rarity:card.rarity,rect:[x,y,w,h]});record(page,'card_'+i,[x,y,w,h],card.name);});
 K.button(ctx,160,958,400,60,'返回抽卡',{kind:'primary',size:28});record(page,'return',[160,958,400,60],'Return to main');
 save(page,canvas,{gold:60,tickets:30,card_ids:state.card_ids,fixture:'Same existing historical ten-result IDs/order; history view retains promotional-main30ticket wallet; current formal names/rare-blue source applied; not real-account records'},{cards,panel:[46,214,628,824],source_preserved:'Existing08result never re-rendered or modified'});
}
(async()=>{
 await K.initAssets();poster=await K.loadImage(path.join(__dirname,'illustrations/poster.png'));arena=await K.loadImage(path.join(BASE,'map_refinement/illustrations/forest-arena.png'));
 posterFeathered=K.createCanvas(720,960);const pf=posterFeathered.getContext('2d');pf.drawImage(poster,0,0,720,960);pf.globalCompositeOperation='destination-in';const fade=pf.createLinearGradient(0,0,0,960);fade.addColorStop(0,'rgba(255,255,255,0)');fade.addColorStop(.15,'rgba(255,255,255,1)');fade.addColorStop(1,'rgba(255,255,255,1)');pf.fillStyle=fade;pf.fillRect(0,0,720,960);pf.globalCompositeOperation='source-over';
 for(const a of sourceArt.assets){if(sha(a.path)!==a.sha256)throw Error('Formal art changed '+a.id);portraits[a.id]=crop(await K.loadImage(a.path),a.alpha_visible_bbox);}
 const mousePath=path.join(BASE,'native_components/illustrations/gray-mouse-hero.png'),mouseFull=await K.loadImage(mousePath),mc=K.createCanvas(mouseFull.width,mouseFull.height),cx=mc.getContext('2d');cx.drawImage(mouseFull,0,0);const raw=cx.getImageData(0,0,mc.width,mc.height).data;let l=mc.width,t=mc.height,r=0,b=0;for(let i=0;i<raw.length;i+=4)if(raw[i+3]>0){let p=i/4,x=p%mc.width,y=Math.floor(p/mc.width);l=Math.min(l,x);r=Math.max(r,x+1);t=Math.min(t,y);b=Math.max(b,y+1);}mouseBox=[l,t,r,b];mouse=crop(mouseFull,mouseBox);
 const tenFile=path.join(BASE,'core_pages/08_gacha_ten_result.png'),protectedTen=sha(tenFile);if(protectedTen!=='1C34FFFA67145E1DD6A75D7E19E79E5E879322BAFCF80D792AD2BBDBC3C179BC')throw Error('Ten-result baseline changed');
 save('06_gacha_empty',mainScreen('06_gacha_empty',30).canvas,{gold:60,tickets:30,buttons_enabled:[true,true],recent_count:10,fixture:'Source-supported30before draw: cost1 leads to existing29opening; cost10 leads to retained20ten-result; promotional main/history share30ticket wallet'},{poster_rect:[0,126,720,960],poster_source:'illustrations/poster.png',recent_button:[508,142,184,54],poster_transition:'Only detail-free green gradient under top feather; no second forest scene or double-exposure'});
 opening();hero();history();save('11_gacha_no_tickets',mainScreen('11_gacha_no_tickets',0).canvas,{gold:60,tickets:0,buttons_enabled:[false,false],fixture:'Retains prior zero-ticket availability state with the same new poster'},{poster_rect:[0,126,720,960],poster_source:'illustrations/poster.png'});
 if(sha(tenFile)!==protectedTen)throw Error('Protected08 mutated');
 const layout={request_id:'REQ-20261012-GACHA-MAP-REFINEMENT',scope:'Five static gacha candidates only; user-authorized main/history layout redesign, no runtime implementation',design_canvas:[720,1280],renderer:'render_gacha.cjs',renderer_sha256:sha(__filename),kit_sha256:sha(path.join(BASE,'native_components/common.cjs')),source_refs:['../core_pages/native-scene-data.json','../core_pages/native-art-sources.json'],protected_ten:{file:'../core_pages/08_gacha_ten_result.png',bytes:fs.statSync(tenFile).size,sha256:protectedTen},ui_override:'Main records table replaced by full promotional art and secondary record button per explicit user request; opening feedback moved above busy CTAs to eliminate old overlap.',new_records_data_source:'Existing ten-result fixture, current authoritative original card art/name/rarity',illustrations:[{file:'illustrations/poster.png',sha256:sha(path.join(__dirname,'illustrations/poster.png'))},{file:'../map_refinement/illustrations/forest-arena.png',sha256:sha(path.join(BASE,'map_refinement/illustrations/forest-arena.png'))}],controls,outputs,status:'STATIC_CANDIDATES_AWAITING_LEAD_ART_REVIEW'};
 fs.writeFileSync(path.join(__dirname,'receipt.json'),JSON.stringify(layout,null,2)+'\n');console.log(JSON.stringify(outputs.map(x=>({file:x.file,sha256:x.sha256})),null,2));
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
