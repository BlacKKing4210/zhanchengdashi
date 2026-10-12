/* PNG-only account/room art previews. Does not run or edit the game. */
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const kit=require('../native_components/common.cjs');
const ROOT=path.resolve(__dirname,'../../../../..');
const OUT=__dirname,FULL=path.resolve(__dirname,'..');
const contract=JSON.parse(fs.readFileSync(path.join(OUT,'layout_contract.json'),'utf8'));
const C=kit.C;
const rel=p=>path.relative(ROOT,p).replace(/\\/g,'/');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
let controls=[],pages=[];
const R=(id)=>contract.rects[id];
function record(id,rect,kind,label,state){controls.push({id,rect,kind,label,state});}
function p(ctx,rect,opts={}){kit.panel(ctx,...rect,opts);}
function t(ctx,label,rect,size=24,opts={}){kit.text(ctx,label,...rect,size,opts);}
function bt(ctx,id,rect,label,opts={}){record(id,rect,'button',label,opts.enabled===false?'disabled':'enabled');kit.button(ctx,...rect,label,opts);}
function field(ctx,id,rect,value,placeholder=false){record(id,rect,'field',value,'editable');p(ctx,rect,{fill:placeholder?'#ede7d8':'#e3ddce',line:2,radius:9});t(ctx,value,[rect[0]+12,rect[1],rect[2]-24,rect[3]],22,{color:placeholder?'#6c706f':C.ink,bold:!placeholder});}
function line(ctx,x1,y1,x2,y2){ctx.save();ctx.beginPath();ctx.moveTo(x1,y1);ctx.lineTo(x2,y2);ctx.strokeStyle='#b8b2a1';ctx.lineWidth=2;ctx.stroke();ctx.restore();}
function stock(ctx){kit.currency(ctx,46,18,186,44,60,'coin');kit.currency(ctx,488,18,186,44,10,'ticket');record('currency_coin',[46,18,186,44],'resource','60','plain');record('currency_ticket',[488,18,186,44],'resource','10','plain');}
function exportPage(id,title,canvas,method,sources,notes=[]){const file=path.join(OUT,id+'.png'),pixels=canvas.toBuffer('image/png');if(!fs.existsSync(file)||!fs.readFileSync(file).equals(pixels))kit.exportPng(canvas,file);pages.push({id,title,canonical_file:id+'.png',sha256:hash(file),width:720,height:1280,render_method:method,source_paths:sources,controls:controls.slice(),notes,status:'NATIVE_REVIEW_PENDING'});controls=[];return file;}
function paint(ctx,img){kit.image(ctx,img,0,0,720,1280);}
function accountBase(lobby){const s=kit.scene();paint(s.ctx,lobby);s.ctx.fillStyle=C.cream;s.ctx.fillRect(0,0,720,130);s.ctx.fillRect(0,1110,720,170);stock(s.ctx);kit.header(s.ctx,'丛林法则',40,68,640,58);kit.nav(s.ctx,'battle');kit.dim(s.ctx,.64);return s;}
function accountShell(ctx,title='设置与账号'){
 p(ctx,R('account_panel'),{fill:C.cream,line:4,radius:18});record('account_panel',R('account_panel'),'panel',title,'open');
 t(ctx,title,R('account_title'),34,{align:'center'});
 bt(ctx,'account_close',R('account_close'),'关闭',{kind:'secondary',size:24});line(ctx,92,264,628,264);
}
function section(ctx,label,y){t(ctx,label,[104,y,120,32],22);line(ctx,230,y+17,616,y+17);}
function accountShared(ctx){bt(ctx,'account_agreement',R('account_agreement'),'玩家协议',{kind:'secondary',size:26});section(ctx,'声音设置',806);bt(ctx,'account_music',R('account_music'),'音乐：开',{kind:'secondary',size:24});bt(ctx,'account_sfx',R('account_sfx'),'音效：开',{kind:'secondary',size:24});}
function avatar(ctx,img,rect,locked=false){ctx.save();if(locked)ctx.globalAlpha=.32;kit.image(ctx,img,...rect,'contain');ctx.restore();}
function nativeRoomBase(accepted){const s=kit.scene();paint(s.ctx,accepted);s.ctx.fillStyle='#80b858';s.ctx.fillRect(32,0,656,1012);s.ctx.fillStyle=C.cream;s.ctx.fillRect(0,1130,720,150);stock(s.ctx);kit.nav(s.ctx,'room');kit.header(s.ctx,'互联网房间',40,68,640,58,{color:'#fff',outline:4});t(s.ctx,'选择双方人数',R('room_subtitle'),22,{align:'center',color:'#fff',outline:2});for(let i=0;i<3;i++)bt(s.ctx,'room_mode_'+(i+1),[72+200*i,168,176,52],(i+1)+'V'+(i+1),{kind:i===2?'gold':'secondary',size:24});return s;}
function roomTeams(ctx,guest){
 p(ctx,R('room_code_panel'),{line:3});t(ctx,'房间码',[70,248,108,28],21);t(ctx,'723322',[172,244,250,38],30,{align:'center',color:C.purple});bt(ctx,'room_code_copy',R('room_code_copy'),'复制',{kind:'gold',size:22});t(ctx,'已连公网服务器 · 其他玩家输入此码即可加入',[70,284,550,22],15,{bold:false});
 const names=['橘猫队长','晚风放映机','猫尾草','夜航星','星河散步','枫叶车站'];
 for(let side=0;side<2;side++){const rect=R(side?'room_team_b':'room_team_a');p(ctx,rect,{fill:side?'#3e688b':'#c24e2d',line:3});t(ctx,side?'B方·冷色':'A方·暖色',[rect[0],rect[1]+12,rect[2],34],26,{align:'center',color:'#fff',outline:2});
  for(let row=0;row<3;row++){const index=side*3+row,n=index+1,rr=[rect[0]+16,rect[1]+60+126*row,rect[2]-32,106],local=guest&&index===1;
   p(ctx,rr,{fill:local?'#ffd331':'#6ac86a',line:3});const name=n+'号 · '+names[index],status=index===0?(guest?'房主':'房主 · 本机'):(local?'本机 · 未准备':'已准备');record('room_slot_'+n,rr,'participant',name,status);
   t(ctx,name,[rr[0]+14,rr[1]+10,rr[2]-28,26],20);t(ctx,status,[rr[0]+14,rr[1]+42,rr[2]-28,26],18,{color:C.ink});
  }
 }
 p(ctx,R('room_fill'),{line:3});t(ctx,'随机玩家补位',[68,837,190,32],24);kit.toggle(ctx,580,836,72,36,false);record('room_fill_toggle',[580,836,72,36],'toggle','随机玩家补位','OFF');
 bt(ctx,'room_leave',R('room_leave'),'离开房间',{kind:'secondary',size:24});bt(ctx,'room_primary',R('room_primary'),guest?'准备':'开始',{kind:'gold',size:26});
}
async function main(){
 // Existing shared kit must be fully present and identical; initAssets is read-only here.
 for(const id of kit.icons){const svg=path.join(kit.ASSET_ROOT,id+'.svg'),png=path.join(kit.ASSET_ROOT,id+'.png');if(!fs.existsSync(svg)||!fs.existsSync(png)||fs.readFileSync(svg,'utf8')!==kit.svgIcon(id))throw new Error('Shared kit not ready: '+id);}
 await kit.initAssets();
 const acceptedPath=path.join(OUT,'01_room_entry.png'),lobbyPath=path.join(FULL,'root_pages/01_lobby.png');
 const accepted=await kit.loadImage(acceptedPath),lobby=await kit.loadImage(lobbyPath);
 // Preserve accepted entry art; normalize output only, retaining default AI original as evidence.
 {const {canvas,ctx}=kit.scene();paint(ctx,accepted);exportPage('01_room_entry','房间－进入',canvas,'Accepted AI artwork normalized to 720x1280',[rel(acceptedPath)],['Accepted design retained; no native layout parity claim for this retained page.']);}
 // Error is a local state edit of the accepted entry, with the same base and component positions.
 {const {canvas,ctx}=kit.scene();paint(ctx,accepted);
  p(ctx,[128,273,464,38],{fill:C.cream,stroke:C.cream,line:0,radius:15});t(ctx,'服务器连接失败，请检查地址或公网服务',[72,273,576,38],19,{align:'center',color:C.red});
  bt(ctx,'room_create',[113,327,494,81],'创建 3V3 房间',{enabled:false,size:27});
  bt(ctx,'room_join',[452,471,180,72],'加入房间',{enabled:false,size:27});
  record('room_error_base',[0,0,720,1280],'state_source','accepted01','same geometry');
  exportPage('02_room_error','房间－连接失败',canvas,'Native local state edit of accepted entry',[rel(acceptedPath)],['Error state uses accepted entry geometry, no independent layout recreation.']);}
 for(const [id,title,guest] of [['03_room_host','房间－房主',false],['04_room_guest','房间－玩家准备',true]]){const {canvas,ctx}=nativeRoomBase(accepted);roomTeams(ctx,guest);exportPage(id,title,canvas,'AI forest edge plus native controls from current code',[rel(acceptedPath),'scripts/app/main.gd:7730-7850','scripts/app/main.gd:10129-10178']);}
 const animalRoot=path.join(ROOT,'assets/card_art/animals'),cache={};async function animal(id){if(!cache[id])cache[id]=await kit.loadImage(path.join(animalRoot,id+'.png'));return cache[id];}
 // Every account value below is a synthetic fixture, never an actual authenticated account.
 {const {canvas,ctx}=accountBase(lobby);accountShell(ctx);section(ctx,'账号信息',284);p(ctx,[104,318,512,264],{fill:'#fff8e8',line:3});p(ctx,[116,340,96,96],{fill:'#e4f3c5',stroke:'#218ee6',line:4});avatar(ctx,await animal('squirrel'),[123,347,82,82]);record('account_avatar_entry',R('account_avatar_entry'),'avatar','松鼠','selected');t(ctx,'稀有',[116,442,96,25],16,{align:'center',color:'#186ec2'});t(ctx,'点击更换',[116,470,96,24],15,{align:'center',color:C.purple});t(ctx,'用户名',[226,318,108,28],19,{color:C.purple});field(ctx,'account_username',R('account_username'),'小松果');
  t(ctx,'账号ID',[226,414,86,26],18,{color:C.purple});t(ctx,'U-DEMO-20261012',[314,412,280,28],18);t(ctx,'UserID',[226,450,86,26],18,{color:C.purple});t(ctx,'U-DEMO-20261012',[314,448,280,28],17);t(ctx,'密码',[226,488,86,28],18,{color:C.purple});t(ctx,'••••••••',[314,486,154,30],19);bt(ctx,'account_password_view',R('account_password_view'),'查看',{kind:'gold',size:21});bt(ctx,'account_copy',R('account_copy'),'复制',{kind:'gold',size:24});bt(ctx,'account_save',R('account_save'),'保存用户名与头像',{kind:'primary',size:26});t(ctx,'点击头像选择全部动物；用户名允许重名',[104,686,512,20],15,{align:'center',bold:false});accountShared(ctx);bt(ctx,'account_switch',R('account_switch'),'切换账号',{kind:'primary',size:24});bt(ctx,'account_bind',R('account_bind'),'重新登录/绑定',{kind:'secondary',size:23});exportPage('05_account','设置与账号',canvas,'Native synthetic account form; approved AI lobby background',[rel(lobbyPath),'scripts/app/main.gd:7622-7682','scripts/app/main.gd:10049-10113',rel(path.join(animalRoot,'squirrel.png'))],['Only U-DEMO identifiers and literal masked password used.']);}
 {const {canvas,ctx}=accountBase(lobby);accountShell(ctx);section(ctx,'账号信息',284);t(ctx,'账号',[104,334,80,58],21);t(ctx,'密码',[104,416,80,58],21);field(ctx,'login_account',R('login_account'),'输入账号（3–32位）',true);field(ctx,'login_password',R('login_password'),'输入密码（8–72位）',true);bt(ctx,'login_login',R('login_login'),'登录',{kind:'primary',size:26});bt(ctx,'login_register',R('login_register'),'注册',{kind:'secondary',size:26});t(ctx,'连接状态： connected',[104,570,512,30],17);accountShared(ctx);exportPage('06_login','账号－登录注册',canvas,'Native manual login form; safe placeholders',[rel(lobbyPath),'scripts/app/main.gd:7634-7649','scripts/app/main.gd:10077-10090']);}
 {const {canvas,ctx}=accountBase(lobby);accountShell(ctx);t(ctx,'选择要使用的账号',[104,284,512,30],22);line(ctx,104,320,616,320);for(let i=0;i<2;i++){const data=contract.safe_data.switch_rows[i],rr=R(i?'switch_row1':'switch_row0');p(ctx,rr,{fill:data.active?'#fff0b2':C.cream,line:3,radius:10});avatar(ctx,await animal(data.avatar),[rr[0]+7,rr[1]+6,40,40]);t(ctx,data.username,[rr[0]+56,rr[1]+5,300,23],18);t(ctx,data.account+' · '+data.rank,[rr[0]+56,rr[1]+29,320,18],14,{bold:false});t(ctx,data.active?'当前':'切换',[rr[0]+372,rr[1]+13,120,28],18,{align:'right',color:data.active?C.green:C.purple});record('switch_row'+i,rr,'account',data.account,data.active?'current':'switchable');}bt(ctx,'switch_new',R('switch_new'),'新建账号',{kind:'primary',size:26});t(ctx,'创建后立即开始全新游戏',[154,894,412,24],16,{align:'center',bold:false});bt(ctx,'switch_bind',R('switch_bind'),'绑定/登录账号',{kind:'secondary',size:26});exportPage('07_account_switch','账号－切换',canvas,'Native synthetic account switcher',[rel(lobbyPath),'scripts/app/main.gd:7684-7712','scripts/app/main.gd:10117-10122',rel(path.join(animalRoot,'squirrel.png')),rel(path.join(animalRoot,'parrot.png'))],['Two synthetic accounts only; geometry and existing actions retained.']);}
 {const {canvas,ctx}=accountBase(lobby);p(ctx,[20,60,680,1160],{fill:C.cream,line:4,radius:18});record('avatar_panel',[20,60,680,1160],'panel','选择动物头像','open');t(ctx,'选择动物头像',[56,90,490,56],32);bt(ctx,'avatar_close',[564,90,104,56],'关闭',{kind:'secondary',size:23});line(ctx,56,160,668,160);t(ctx,'全部动物 60 · 已解锁 9 · 锁定 51',[56,178,612,28],19,{color:C.mutedInk});
  const rows=fs.readFileSync(path.join(ROOT,'config/tables/cards.csv'),'utf8').replace(/^\uFEFF/,'').split(/\r?\n/).slice(3).filter(x=>x.trim()).map(x=>x.split(',')).filter(x=>x[0]&&fs.existsSync(path.join(animalRoot,x[0]+'.png')));
  if(rows.length!==60)throw new Error('Expected 60 authoritative animal IDs; got '+rows.length);
  const unlocked=new Set(['rabbit','cat','squirrel','parrot','wolf','hippo','monkey','lion','elephant']);const rarity={common:['普通','#479443','#e4edce'],rare:['稀有','#2185cc','#d1e7f2'],epic:['史诗','#8f4ac6','#e4d4f3'],legendary:['传说','#cd731b','#fae3b4']};
  const drawRows=[];for(let i=0;i<20;i++){const [id,name,r]=rows[i],x=56+(i%4)*154,y=214+Math.floor(i/4)*202,rr=[x,y,142,190],u=unlocked.has(id),selected=id==='squirrel',spec=rarity[r]||rarity.common;drawRows.push({id,name,r,rr,u,selected,spec,img:await animal(id)});}
  kit.clip(ctx,56,214,608,924,()=>{for(const a of drawRows){p(ctx,a.rr,{fill:a.selected?'#ffe5a3':a.u?a.spec[2]:'#eee8da',stroke:a.selected?'#966e21':a.u?a.spec[1]:'#bcbebd',line:a.selected?4:2,radius:11});avatar(ctx,a.img,[a.rr[0]+8,a.rr[1]+10,126,92],!a.u);t(ctx,a.name,[a.rr[0]+8,a.rr[1]+108,126,28],18,{align:'center'});t(ctx,a.spec[0],[a.rr[0]+8,a.rr[1]+137,126,23],16,{align:'center',color:a.u?a.spec[1]:C.mutedInk});t(ctx,a.selected?'已选':a.u?'可用':'锁定',[a.rr[0]+8,a.rr[1]+160,126,23],16,{align:'center',color:a.selected?'#8b651c':a.u?C.green:C.mutedInk});record('avatar_'+a.id,a.rr,'avatar',a.name,a.selected?'selected':a.u?'unlocked':'locked');}});
  p(ctx,[660,214,8,924],{fill:'#d6d1c5',line:0,radius:4});p(ctx,[660,214,8,300],{fill:'#8c8b88',line:0,radius:4});kit.wrapped(ctx,'未拥有的头像会显示“锁定”；点击可查看获得方式。',56,1152,608,46,18,{color:C.mutedInk,bold:false});exportPage('08_avatar','账号－头像选择',canvas,'Native 4-column catalog from formal original animal art',[rel(lobbyPath),'scripts/app/ui/account_avatar_picker.gd','config/tables/cards.csv','output/runtime_ui_b_20260906/19_avatar.png','assets/card_art/animals/'],['Synthetic 9-unlocked fixture, matching source visible unlocked states. Fourth-column/partial fifth-row clipping is the source scroll viewport, not hidden footer. Underlying route is account-center lobby.']);}
 {const {canvas,ctx}=accountBase(lobby);accountShell(ctx,'玩家协议');const lines=kit.wrapped(ctx,contract.agreement_text,...R('agreement_text'),24,{bold:false,lineHeight:35});record('agreement_text',R('agreement_text'),'paragraph',contract.agreement_text,'existing');bt(ctx,'agreement_back',R('agreement_back'),'返回账号中心',{kind:'primary',size:26});exportPage('09_agreement','账号－玩家协议',canvas,'Native existing agreement text, no added terms',[rel(lobbyPath),'scripts/app/main.gd:7622-7632','scripts/app/main.gd:10125-10126'],['Agreement text wrapped into '+lines.length+' lines without truncation.']);}
 const old=JSON.parse(fs.readFileSync(path.join(OUT,'subset-manifest.json'),'utf8'));
 old.status='PRODUCED_NATIVE_REVIEW_PENDING';old.native_renderer={path:'native_renderer.cjs',sha256:hash(__filename),kit_path:rel(path.join(FULL,'native_components/common.cjs')),kit_sha256:hash(path.join(FULL,'native_components/common.cjs')),code_sha256:hash(path.join(ROOT,'scripts/app/main.gd')),target_resolution:[720,1280],actual_credentials_used:false,execution_date:'2026-10-12 Asia/Hong_Kong'};
 for(const page of pages){let e=old.images.find(x=>x.id===page.id);if(e){if(!e.ai_history_before_native)e.ai_history_before_native={generated_path:e.generated_path,sha256:e.sha256,prompt:e.prompt,input_paths:e.input_paths,status:e.status};Object.assign(e,page);}else old.images.push(page);}
 fs.writeFileSync(path.join(OUT,'subset-manifest.json'),JSON.stringify(old,null,2)+'\n','utf8');fs.writeFileSync(path.join(OUT,'native-controls.json'),JSON.stringify({schema_version:1,request_id:old.request_id,pages},null,2)+'\n','utf8');
 console.log(JSON.stringify({status:'NATIVE_ACCOUNT_ROOM_PRODUCED',count:pages.length,files:pages.map(x=>({file:x.canonical_file,sha256:x.sha256,width:x.width,height:x.height}))}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
