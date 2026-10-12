const path=require('path');
const K=require('./native_components/common.cjs');
const base=__dirname;
(async()=>{
 await K.initAssets();const W=1328,H=1810,c=K.createCanvas(W,H),x=c.getContext('2d');
 x.fillStyle='#13272b';x.fillRect(0,0,W,H);
 K.text(x,'丛林法则 · 全游戏美术效果',34,20,1260,48,33,{color:'#f5f0df'});
 const count=JSON.parse(require('fs').readFileSync(path.join(base,'manifest.json'),'utf8')).count;
 K.text(x,'6 条主要流程与关键状态 · '+count+' 张效果图 · 未实装',34,71,1260,34,20,{color:'#c6d89b'});
 const pages=[
 ['core_pages/01_home_selected.png','家园 · 建筑与产出'],
 ['core_pages/04_deck_main.png','编组 · 卡牌与升级'],
 ['root_pages/01_lobby.png','大厅 · 段位与对战入口'],
 ['style_master.png','战斗 · 棋盘与反馈基准'],
 ['core_pages/06_gacha_empty.png','抽卡 · 伙伴招募宣传'],
 ['account_room/01_room_entry.png','房间 · 模式与加入']];
 for(let i=0;i<pages.length;i++){
  const a=34+(i%3)*432,b=126+Math.floor(i/3)*808;
  const image=await K.loadImage(path.join(base,pages[i][0]));
  x.fillStyle='#f3ebd7';x.fillRect(a,b,400,712);x.drawImage(image,a,b,400,712);
  K.text(x,pages[i][1],a,b+727,400,34,23,{color:'#f5f0df'});
 }
 K.text(x,'普通货币：外凸图标＋深色胶囊＋描边数量；无进度、无商城加号。',34,1742,1260,36,20,{color:'#b9cbc4'});
 K.save(c,path.join(base,'overview.png'));console.log(JSON.stringify({output:'overview.png',width:W,height:H,source_views:6,runtime_changes:false}));
})().catch(e=>{console.error(e);process.exitCode=1;});
