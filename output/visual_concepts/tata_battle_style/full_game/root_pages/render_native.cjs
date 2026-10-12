/* User-authorized native PNG preview composition only. Never imports/runs Godot. */
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const K=require('../native_components/common.cjs');
const S=require('./skin_world.cjs');
const ROOT=path.resolve(__dirname,'../../../../..');
const BASE=path.resolve(__dirname,'..');
const controls=[];
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
function record(page,id,rect){controls.push({page,id,rect});}
function outline(ctx,label,rect,size=22,color=K.C.ink,align='left'){
 K.text(ctx,label,...rect,size,{color,align});
}
async function sourceLayer(src,inverseAlpha=0){
 const {canvas,ctx}=K.scene();const img=await K.loadImage(src);K.image(ctx,img,0,0,720,1280);
 if(inverseAlpha){const raw=ctx.getImageData(0,0,720,1280);for(let i=0;i<raw.data.length;i+=4){for(let c=0;c<3;c++)raw.data[i+c]=Math.min(255,Math.round(raw.data[i+c]/(1-inverseAlpha)));}ctx.putImageData(raw,0,0);}
 return{canvas,ctx};
}
function top(ctx,p,values,mode='classic'){
 K.currency(ctx,46,18,186,44,values.gold,'coin');record(p,'gold',[46,18,186,44]);
 K.currency(ctx,488,18,186,44,values.ticket,'ticket');record(p,'ticket',[488,18,186,44]);
 if(mode!=='team'){
  K.panel(ctx,250,18,220,44,{fill:K.C.navy,line:3,radius:12});
  K.text(ctx,values.middle||'黄金3星 VS 黄金3星',250,18,220,44,20,{align:'center',color:'#fff',outline:2});record(p,'rank_or_time',[250,18,220,44]);
 }
 K.pauseMark(ctx,610,mode==='team'?116:78,62,56);record(p,'pause',[610,mode==='team'?116:78,62,56]);
}
function instruction(ctx,p,title,body){
 const r=[26,1132,668,118];K.panel(ctx,...r,{fill:K.C.cream,line:4,radius:14});record(p,'battle_info',r);
 K.text(ctx,title,48,1145,624,34,25);K.wrapped(ctx,body,48,1185,624,58,20,{lineHeight:25});
}
function score(ctx,p,side,count){
 const x=side===0?46:374,r=[x,70,300,34];K.panel(ctx,...r,{fill:K.C.navy,line:3,stroke:side===0?K.C.gold:K.C.ink,radius:7});
 const colors=side===0?[S.palette.yellow,S.palette.orange,S.palette.pink]:[S.palette.blue,S.palette.purple,S.palette.green];
 colors.forEach((c,i)=>{ctx.beginPath();ctx.arc(x+16+15*i,87,5,0,Math.PI*2);ctx.fillStyle='rgb('+c.join(',')+')';ctx.fill();ctx.strokeStyle=K.C.ink;ctx.lineWidth=1.5;ctx.stroke();});
 K.text(ctx,side===0?'A方 · 我方':'B方 · 敌方',x+64,77,126,20,18,{color:'#fff'});
 K.text(ctx,count+' 格',x+194,74,94,26,21,{align:'right',color:'#fff'});record(p,'team_score_'+side,r);
}
function player(ctx,page,y,entry,self=false){
 const h=self?112:72,w=entry.scroll?524:536,r=[92,y,w,h];
 K.panel(ctx,...r,{fill:self?'#f7edcf':'#fffaf0',line:self?2.5:1.5,stroke:self?'#d8b746':'#beb6a8',radius:11});
 ctx.beginPath();ctx.arc(124,y+h/2,20,0,Math.PI*2);ctx.fillStyle=entry.rank===1?K.C.gold:'#d4b8e6';ctx.fill();ctx.lineWidth=2;ctx.strokeStyle=K.C.ink;ctx.stroke();
 K.text(ctx,String(entry.rank),104,y+h/2-17,40,34,24,{align:'center'});
 const name='第'+entry.rank+'名  '+entry.name+(self?'  自己':'');
 K.text(ctx,name,158,y+8,w-82,28,21);
 K.text(ctx,entry.old+'  →  '+entry.next,158,y+h-34,w-150,26,18,{color:K.C.purple});
 K.icon(ctx,'star',92+w-94,y+h/2-20,40,40);
 const delta=entry.delta>0?'+'+entry.delta:String(entry.delta);
 K.text(ctx,delta,92+w-58,y+h/2-13,44,26,21,{align:'right',color:entry.delta>0?K.C.green:entry.delta<0?K.C.red:K.C.blue});
 record(page,self?'local_result':'other_'+entry.name,r);
}
async function pause(){
 const p='06_pause';const src=path.join(BASE,'style_master.png');const {canvas,ctx}=await sourceLayer(src);
 top(ctx,p,{gold:60,ticket:10});
 instruction(ctx,p,'1V1 菱形战场 · 拖动查看地图','点击己方可连接地块购买；防御塔价格随本局购买次数递增。');
 K.dim(ctx,.48);K.panel(ctx,120,430,480,330,{line:4,radius:14});record(p,'pause_panel',[120,430,480,330]);
 K.text(ctx,'战斗暂停',120,468,480,52,38,{align:'center'});
 K.button(ctx,184,552,352,68,'继续战斗',{kind:'primary',size:30});record(p,'continue',[184,552,352,68]);
 K.button(ctx,184,644,352,68,'退出战斗',{kind:'secondary',size:30});record(p,'exit',[184,644,352,68]);
 const dst=path.join(__dirname,p+'.png');K.exportPng(canvas,dst);return{page:p,source:src,source_sha256:sha(src),path:p+'.png',sha256:sha(dst),underlay_alpha:.48};
}
const cases=[
 {page:'07_victory',source:'temp/qa/result-reward-area-20260907/victory-720.png',title:'胜利',color:K.C.gold,gold:146,ticket:16,middle:'青铜2星 VS 青铜1星',mode:'classic',self:{rank:1,name:'神秘玩家',old:'青铜2星',next:'青铜3星',delta:1},others:[{rank:2,name:'松果队长',old:'青铜1星',next:'青铜1星',delta:-1}],left:{type:'coin',value:'+12'},right:'+3',bottom:['1V1 十字战场 · 拖动查看地图','点击己方可连接地块购买；防御塔价格随本局购买次数递增。']},
 {page:'08_defeat',source:'temp/qa/result-reward-area-20260907/team-loss-top-720.png',title:'失败',color:'#ee5b65',gold:146,ticket:17,mode:'team',self:{rank:1,name:'林间信使',old:'青铜3星',next:'青铜2星',delta:-1},others:[{rank:2,name:'青柠苏打',old:'青铜3星',next:'青铜2星',delta:-1,scroll:true},{rank:3,name:'晚风放映机',old:'青铜3星',next:'青铜2星',delta:-1,scroll:true},{rank:4,name:'雾岛来客',old:'青铜3星',next:'青铜6星',delta:3,scroll:true}],left:{type:'star',value:'-1'},right:'+1',bottom:['拖动查看地图，点击地块查看信息','单位自动选择最近敌人；点击己方可连接地块可购买。']},
 {page:'09_ffa_result',source:'temp/qa/result-reward-area-20260907/ffa-720.png',title:'第1名',color:K.C.gold,gold:146,ticket:22,middle:'06:00 第6/6',mode:'ffa',self:{rank:1,name:'我',old:'青铜2星',next:'青铜5星',delta:3},others:[{rank:1,name:'青柠苏打',old:'青铜2星',next:'青铜5星',delta:3,scroll:true},{rank:2,name:'晚风放映机',old:'青铜2星',next:'青铜4星',delta:2,scroll:true},{rank:3,name:'雾岛来客',old:'青铜2星',next:'青铜4星',delta:2,scroll:true}],left:{type:'star',value:'+3'},right:'+5',bottom:['拖动查看地图，点击地块查看信息','单位自动选择最近敌人；点击己方可连接地块可购买。']}
];
async function result(d){
 const src=path.join(ROOT,d.source),{canvas,ctx}=await sourceLayer(src,.42);
 const world_skin=await S.styleWorld(ctx,{modal:true,lobby:path.join(__dirname,'01_lobby.png')});
 top(ctx,d.page,d,d.mode);if(d.mode==='team'){score(ctx,d.page,0,129);score(ctx,d.page,1,129);}
 instruction(ctx,d.page,...d.bottom);K.dim(ctx,.42);
 K.panel(ctx,60,176,600,824,{fill:K.C.cream,line:4,radius:14});record(d.page,'result_panel',[60,176,600,824]);
 K.clip(ctx,60,176,600,82,()=>K.panel(ctx,60,176,600,82,{fill:K.C.navy,line:0,radius:14}));
 K.text(ctx,d.title,60,200,600,56,42,{align:'center',color:d.color,outline:2});
 K.text(ctx,'我的结算',92,264,536,28,22,{align:'center',color:K.C.purple});
 player(ctx,d.page,298,d.self,true);
 K.text(ctx,'其他玩家（上下滑动查看）',92,426,536,30,21);
 K.panel(ctx,92,468,536,276,{fill:'#e7dfce',line:0,radius:8});record(d.page,'other_results',[92,468,536,276]);
 d.others.forEach((e,i)=>player(ctx,d.page,468+i*82,e));
 if(d.others.length>1){K.panel(ctx,621,472,4,268,{fill:'#b9b3aa',line:0,radius:2});K.panel(ctx,621,472,4,144,{fill:K.C.purple,line:0,radius:2});}
 K.panel(ctx,92,764,536,116,{fill:'#fffaf0',line:2,stroke:'#c1b8a9',radius:11});record(d.page,'rewards',[92,764,536,116]);
 K.text(ctx,'本场奖励',108,774,504,28,22,{align:'center'});
 K.reward(ctx,176,816,164,44,d.left.value,d.left.type,{fontSize:25});K.reward(ctx,380,816,164,44,d.right,'ticket',{fontSize:25});
 K.button(ctx,190,900,340,64,'关闭',{size:30});record(d.page,'close',[190,900,340,64]);
 const dst=path.join(__dirname,d.page+'.png');K.exportPng(canvas,dst);return{page:d.page,source:d.source,source_sha256:sha(src),path:d.page+'.png',sha256:sha(dst),underlay_alpha:.42,world_skin,underlay_method:'Undo known source0.42 dim, skin only source field/background pixels, redraw exact UI, apply one uniform0.42 layer; source map/object geometry retained.'};
}
async function mode(d){
 const src=path.join(ROOT,d.source),{canvas,ctx}=await sourceLayer(src);
 const world_skin=await S.styleWorld(ctx,{lobby:path.join(__dirname,'01_lobby.png')});
 top(ctx,d.page,d,d.kind);if(d.kind==='team'){score(ctx,d.page,0,108);score(ctx,d.page,1,108);}
 if(d.kind==='ffa'){
  K.panel(ctx,500,148,148,184,{fill:K.C.navy,line:3,radius:10});record(d.page,'leaderboard',[500,148,148,184]);
  K.text(ctx,'地块排名',508,153,132,28,20,{align:'center',color:'#fff'});
  const cs=[S.palette.yellow,S.palette.green,S.palette.purple,S.palette.blue,S.palette.orange,S.palette.pink].map(c=>'rgb('+c.join(',')+')');
  for(let i=0;i<6;i++){const y=184+i*22;if(i===4)K.panel(ctx,508,y,132,21,{fill:'#f7db69',line:1.5,stroke:K.C.gold,radius:4});ctx.beginPath();ctx.arc(517,y+10,4.5,0,Math.PI*2);ctx.fillStyle=cs[i];ctx.fill();K.text(ctx,(i+1)+'号',526,y,47,21,17,{color:i===4?K.C.ink:'#fff'});K.text(ctx,'55格',580,y,60,21,17,{align:'right',color:i===4?K.C.ink:'#fff'});}
 }
 instruction(ctx,d.page,...d.bottom);const dst=path.join(__dirname,d.page+'.png');K.exportPng(canvas,dst);
 return{page:d.page,source:d.source,source_sha256:sha(src),path:d.page+'.png',sha256:sha(dst),world_skin,method:'Original source map/object geometry; low-density field palette and accepted AI forest only in edge-connected outside-map blank pixels; exact shared native HUD, no map regeneration.'};
}
(async()=>{
 await K.initAssets();const outputs=[await pause()];for(const d of cases)outputs.push(await result(d));
 outputs.push(await mode({page:'11_team_battle',source:'temp/qa/all-animals-audit-20260906/hex-3v3-720.png',gold:72,ticket:10,kind:'team',bottom:['空地','已解锁区域，可作为继续扩张的连接点。']}));
 outputs.push(await mode({page:'12_ffa_battle',source:'temp/qa/all-animals-audit-20260906/hex-ffa-720.png',gold:72,ticket:10,middle:'06:00 第5/6',kind:'ffa',bottom:['拖动查看地图，点击地块查看信息','单位自动选择最近敌人；点击己方可连接地块可购买。']}));
 const receipt={request_id:'REQ-20261011-TATA-FULL-GAME-PREVIEW',phase:'USER_AUTHORIZED_NATIVE_COMPOSITION',canvas:[720,1280],runtime_changes:false,kit_sha256:sha(path.join(BASE,'native_components/common.cjs')),outputs,controls,source_geometry:'scripts/app/main.gd source rects',acceptance:'PENDING_INDEPENDENT_STATIC_ART_REVIEW'};
 fs.writeFileSync(path.join(__dirname,'native-render-receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify({status:'NATIVE_ROOT_RENDERED',count:outputs.length,outputs:outputs.map(x=>x.path)}));
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
