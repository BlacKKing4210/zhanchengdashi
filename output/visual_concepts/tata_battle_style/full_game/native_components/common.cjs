/* Native preview-only UI kit. NO_RUNTIME. User-authorized exact PNG composition. */
const fs = require('fs');
const path = require('path');
const MODULES = process.env.CODEX_NODE_MODULES || 'C:/Users/76398/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { createCanvas, loadImage, GlobalFonts } = require(path.join(MODULES, '@napi-rs/canvas'));
const KIT_ROOT = __dirname;
const ASSET_ROOT = path.join(KIT_ROOT, 'icons');
for (const f of ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/msyhbd.ttc']) {
  if (fs.existsSync(f)) GlobalFonts.registerFromPath(f, 'Microsoft YaHei');
}
const C = Object.freeze({ink:'#10172c',navy:'#1d2e4c',navyLight:'#2a4264',cream:'#fbf5e6',lime:'#8bec38',limeDark:'#6ac328',gold:'#ffd331',blue:'#51caff',muted:'#c5c6c8',mutedInk:'#5c6167',purple:'#6551b9',green:'#297844',red:'#b53139'});
const sw='stroke="#10172c" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"';
const iconMarkup = {
  coin: '<circle cx="52" cy="52" r="39" fill="#ef9d0f" '+sw+'/><circle cx="52" cy="52" r="31" fill="#ffcb16" stroke="#ffe451" stroke-width="5"/><path d="M32 43 Q33 27 51 26" fill="none" stroke="#fff5b5" stroke-width="5" stroke-linecap="round"/><circle cx="52" cy="52" r="22" fill="none" stroke="#eeb315" stroke-width="3"/>',
  ticket: '<g transform="rotate(-43 52 52)"><path d="M18 29 H86 V42 Q75 42 75 52 Q75 62 86 62 V75 H18 V62 Q29 62 29 52 Q29 42 18 42 Z" fill="#45cafa" '+sw+'/><path d="M28 35 H77 V41 Q67 44 67 52 Q67 60 77 64 V69 H28 V64 Q38 60 38 52 Q38 44 28 41 Z" fill="#8be6ff" stroke="#14a6e6" stroke-width="3"/><ellipse cx="52" cy="57" rx="12" ry="9" fill="#087ee0"/><ellipse cx="39" cy="46" rx="5" ry="6" fill="#087ee0"/><ellipse cx="50" cy="41" rx="5" ry="6" fill="#087ee0"/><ellipse cx="62" cy="43" rx="5" ry="6" fill="#087ee0"/><ellipse cx="68" cy="53" rx="4" ry="5" fill="#087ee0"/></g>',
  nav_home: '<path d="M22 47 L52 21 L83 47 V88 H61 V64 H43 V88 H22 Z" fill="#fff4d9" '+sw+'/><path d="M15 47 L52 12 L90 47 L82 55 L52 28 L23 55 Z" fill="#f8781e" '+sw+'/><path d="M20 45 L52 18 L83 45" fill="none" stroke="#ffb550" stroke-width="3"/>',
  nav_deck: '<rect x="20" y="19" width="46" height="62" rx="6" fill="#ffda62" '+sw+'/><rect x="39" y="29" width="46" height="62" rx="6" fill="#ba8cf1" '+sw+'/><path d="M47 38 H76 V79" fill="none" stroke="#d7b8ff" stroke-width="4" stroke-linecap="round"/>',
  nav_battle: '<g transform="rotate(-43 52 52)"><path d="M45 12 H59 V70 L52 78 L45 70 Z" fill="#ecf6ff" '+sw+'/><path d="M44 12 L52 5 L60 12" fill="#fff" '+sw+'/><rect x="33" y="65" width="38" height="10" rx="3" fill="#e5a735" '+sw+'/><rect x="46" y="75" width="12" height="21" rx="3" fill="#9c5227" '+sw+'/></g><g transform="rotate(43 52 52)"><path d="M45 12 H59 V70 L52 78 L45 70 Z" fill="#ecf6ff" '+sw+'/><path d="M44 12 L52 5 L60 12" fill="#fff" '+sw+'/><rect x="33" y="65" width="38" height="10" rx="3" fill="#e5a735" '+sw+'/><rect x="46" y="75" width="12" height="21" rx="3" fill="#9c5227" '+sw+'/></g>',
  nav_gacha: '<g transform="rotate(-43 52 52)"><path d="M18 29 H86 V42 Q75 42 75 52 Q75 62 86 62 V75 H18 V62 Q29 62 29 52 Q29 42 18 42 Z" fill="#ffd52c" '+sw+'/><path d="M28 35 H77 V41 Q67 44 67 52 Q67 60 77 64 V69 H28 V64 Q38 60 38 52 Q38 44 28 41 Z" fill="#ffe990" stroke="#f3ac16" stroke-width="3"/><ellipse cx="52" cy="57" rx="12" ry="9" fill="#b4550b"/><ellipse cx="39" cy="46" rx="5" ry="6" fill="#b4550b"/><ellipse cx="50" cy="41" rx="5" ry="6" fill="#b4550b"/><ellipse cx="62" cy="43" rx="5" ry="6" fill="#b4550b"/><ellipse cx="68" cy="53" rx="4" ry="5" fill="#b4550b"/></g>',
  nav_room: '<path d="M19 90 V49 Q19 12 52 12 Q86 12 86 49 V90 Z" fill="#ddd5c2" '+sw+'/><path d="M30 89 V48 Q30 24 52 24 Q75 24 75 48 V89 Z" fill="#a96336" '+sw+'/><path d="M41 35 V83 M53 30 V83 M65 35 V83" fill="none" stroke="#804323" stroke-width="3"/><ellipse cx="66" cy="62" rx="5" ry="7" fill="#ffe56c" stroke="#82481e" stroke-width="3"/>',
  star: '<path d="M52 11 L64 36 L92 40 L72 59 L77 89 L52 75 L27 89 L32 59 L12 40 L40 36 Z" fill="#ffd445" '+sw+'/>',
  heart: '<path d="M52 84 L18 50 Q2 23 26 17 Q43 12 52 31 Q61 12 78 17 Q102 23 86 50 Z" fill="#f64e58" '+sw+'/>',
  paw: '<ellipse cx="52" cy="64" rx="22" ry="18" fill="#ff9b21" '+sw+'/><ellipse cx="23" cy="41" rx="8" ry="11" fill="#ff9b21" '+sw+'/><ellipse cx="42" cy="27" rx="8" ry="11" fill="#ff9b21" '+sw+'/><ellipse cx="63" cy="27" rx="8" ry="11" fill="#ff9b21" '+sw+'/><ellipse cx="82" cy="41" rx="8" ry="11" fill="#ff9b21" '+sw+'/>'
};
function svgIcon(id) {
 if(!iconMarkup[id]) throw new Error('Unknown formal icon ID: '+id);
 return '<svg xmlns="http://www.w3.org/2000/svg" width="104" height="104" viewBox="0 0 104 104">'+iconMarkup[id]+'</svg>';
}
const images={};
async function initAssets(opts={}){
 if(opts.build)fs.mkdirSync(ASSET_ROOT,{recursive:true});
 for(const id of Object.keys(iconMarkup)){
  const svg=svgIcon(id), svgFile=path.join(ASSET_ROOT,id+'.svg'),pngFile=path.join(ASSET_ROOT,id+'.png');
  if(!fs.existsSync(svgFile)||fs.readFileSync(svgFile,'utf8')!==svg){if(!opts.build)throw new Error('Canonical icon source mismatch: '+id);fs.writeFileSync(svgFile,svg,'utf8');}
  if(!fs.existsSync(pngFile)){if(!opts.build)throw new Error('Canonical icon PNG missing: '+id);images[id]=await loadImage(Buffer.from(svg));const cn=createCanvas(104,104),ct=cn.getContext('2d');ct.drawImage(images[id],0,0);fs.writeFileSync(pngFile,cn.toBuffer('image/png'));}
  images[id]=await loadImage(pngFile);
 }
 return images;
}
function scene(fill=C.cream,w=720,h=1280){const canvas=createCanvas(w,h),ctx=canvas.getContext('2d');ctx.fillStyle=fill;ctx.fillRect(0,0,w,h);ctx.lineJoin='round';ctx.lineCap='round';return {canvas,ctx};}
function roundPath(ctx,x,y,w,h,r=12){
 r=Math.min(r,w/2,h/2);ctx.beginPath();ctx.moveTo(x+r,y);ctx.lineTo(x+w-r,y);ctx.quadraticCurveTo(x+w,y,x+w,y+r);ctx.lineTo(x+w,y+h-r);ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h);ctx.lineTo(x+r,y+h);ctx.quadraticCurveTo(x,y+h,x,y+h-r);ctx.lineTo(x,y+r);ctx.quadraticCurveTo(x,y,x+r,y);ctx.closePath();
}
function panel(ctx,x,y,w,h,opts={}){
 ctx.save();roundPath(ctx,x,y,w,h,opts.radius===undefined?12:opts.radius);
 ctx.fillStyle=opts.fill||C.cream;ctx.fill();
 const line=opts.line===undefined?3:opts.line;if(line>0){ctx.strokeStyle=opts.stroke||C.ink;ctx.lineWidth=line;ctx.stroke();}ctx.restore();
}
function font(ctx,size=24,bold=true){ctx.font=(bold?'bold ':'')+size+'px "Microsoft YaHei"';}
function text(ctx,value,x,y,w,h,size=24,opts={}){
 value=String(value);ctx.save();font(ctx,size,opts.bold!==false);ctx.textBaseline='middle';ctx.textAlign=opts.align||'left';
 const measured=ctx.measureText(value).width;
 if(!opts.allowOverflow && measured>w+1){ctx.restore();throw new Error('Text overflow '+JSON.stringify({value,measured,w,size,x,y}));}
 const tx=opts.align==='center'?x+w/2:opts.align==='right'?x+w:x;
 const ty=y+h/2;
 if(opts.outline){ctx.strokeStyle=opts.outlineColor||C.ink;ctx.lineWidth=opts.outline;ctx.strokeText(value,tx,ty);}
 ctx.fillStyle=opts.color||C.ink;ctx.fillText(value,tx,ty);ctx.restore();return measured;
}
function multiline(ctx,lines,x,y,w,h,size=24,opts={}){
 if(!Array.isArray(lines))lines=String(lines).split('\n');
 const gap=opts.lineHeight||size*1.38;if(lines.length*gap>h+1)throw new Error('Text lines overflow height');
 lines.forEach((line,i)=>text(ctx,line,x,y+i*gap,w,gap,size,opts));
}
function wrapped(ctx,value,x,y,w,h,size=24,opts={}){
 ctx.save();font(ctx,size,opts.bold!==false);const lines=[];let line='';
 for(const ch of String(value)){if(ch==='\n'){lines.push(line);line='';continue;}if(ctx.measureText(line+ch).width>w&&line){lines.push(line);line=ch;}else line+=ch;}
 if(line)lines.push(line);ctx.restore();multiline(ctx,lines,x,y,w,h,size,opts);return lines;
}
function icon(ctx,id,x,y,w,h=w){if(!images[id])throw new Error('await kit.initAssets() before icon()');ctx.drawImage(images[id],x,y,w,h);}
function currency(ctx,x,y,w,h,value,type='coin',opts={}){
 if(type!=='coin'&&type!=='ticket'&&type!=='star')throw new Error('Unknown currency '+type);
 panel(ctx,x,y,w,h,{fill:C.navy,line:3,radius:14});
 const size=opts.iconSize||h+26;
 icon(ctx,type,x-23,y+(h-size)/2,size,size);
 text(ctx,value,x+size-13,y,w-size+1,h,opts.fontSize||30,{align:'right',color:'#fff',outline:3});
}
function reward(ctx,x,y,w,h,value,type,opts={}){
 panel(ctx,x,y,w,h,{fill:opts.fill||'#eee6d5',stroke:opts.stroke||'#c8c0b2',line:2,radius:9});
 const size=opts.iconSize||h-4;icon(ctx,type,x+2,y+(h-size)/2,size,size);
 text(ctx,value,x+size+7,y,w-size-17,h,opts.fontSize||24,{align:'right',color:opts.color||C.ink});
}
function button(ctx,x,y,w,h,label,opts={}){
 const enabled=opts.enabled!==false,kind=opts.kind||'primary';
 const fill=!enabled?C.muted:kind==='secondary'?C.navy:kind==='gold'?C.gold:C.lime;
 panel(ctx,x,y,w,h,{fill,stroke:enabled?C.ink:'#7b7e84',line:3,radius:13});
 const color=!enabled?C.mutedInk:kind==='secondary'?'#fff':C.ink;
 text(ctx,label,x+10,y,w-20,h,opts.size||28,{align:'center',color,outline:enabled&&kind==='secondary'?2:0});
}
function nav(ctx,active,opts={}){
 const ids=['home','deck','battle','gacha','room'],labels=['家园','编组','战斗','抽卡','房间'],icons=['nav_home','nav_deck','nav_battle','nav_gacha','nav_room'];
 if(typeof active==='number')active=ids[active];
 const y=opts.y===undefined?1148:opts.y,w=opts.w||138,h=opts.h||122,step=opts.step||144,x0=opts.x===undefined?3:opts.x;
 for(let i=0;i<ids.length;i++){const x=x0+i*step,selected=ids[i]===active;panel(ctx,x,y,w,h,{fill:selected?C.lime:C.navy,line:3,radius:14});icon(ctx,icons[i],x+(w-74)/2,y+7,74,74);text(ctx,labels[i],x+8,y+83,w-16,32,24,{align:'center',color:selected?C.ink:'#fff',outline:selected?0:2});}
}
function header(ctx,label,x=40,y=68,w=640,h=58,opts={}){text(ctx,label,x,y,w,h,opts.size||42,{align:'center',color:opts.color||C.ink,...opts});}
function dim(ctx,alpha=.42){ctx.save();ctx.fillStyle='rgba(0,0,0,'+alpha+')';ctx.fillRect(0,0,ctx.canvas.width,ctx.canvas.height);ctx.restore();}
function clip(ctx,x,y,w,h,callback){ctx.save();ctx.beginPath();ctx.rect(x,y,w,h);ctx.clip();callback();ctx.restore();}
function image(ctx,img,x,y,w,h,mode='stretch'){
 if(mode==='stretch'){ctx.drawImage(img,x,y,w,h);return;}
 const s=mode==='contain'?Math.min(w/img.width,h/img.height):Math.max(w/img.width,h/img.height);
 const dw=img.width*s,dh=img.height*s;clip(ctx,x,y,w,h,()=>ctx.drawImage(img,x+(w-dw)/2,y+(h-dh)/2,dw,dh));
}
function overlay(ctx,x,y,w,h,alpha=.42){dim(ctx,alpha);panel(ctx,x,y,w,h,{fill:C.cream,line:4,radius:14});}
function pauseMark(ctx,x=610,y=78,w=62,h=56){panel(ctx,x,y,w,h,{fill:C.navy,line:3,radius:12});ctx.fillStyle='#fff';ctx.fillRect(x+19,y+15,8,26);ctx.fillRect(x+35,y+15,8,26);}
function toggle(ctx,x,y,w,h,on){panel(ctx,x,y,w,h,{fill:on?'#4dab44':'#747c90',line:2,radius:h/2});ctx.beginPath();ctx.arc(x+(on?w-h/2:h/2),y+h/2,h/2-5,0,Math.PI*2);ctx.fillStyle='#fff';ctx.fill();ctx.strokeStyle=C.ink;ctx.lineWidth=2;ctx.stroke();}
function exportPng(canvas,file){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,canvas.toBuffer('image/png'));return file;}
module.exports={C,KIT_ROOT,ASSET_ROOT,createCanvas,loadImage,GlobalFonts,initAssets,scene,createPage:scene,panel,rr:panel,roundPath,font,text,multiline,wrapped,icon,currency,resource:currency,reward,button,nav,header,dim,clip,image,overlay,pauseMark,toggle,exportPng,save:exportPng,svgIcon,icons:Object.keys(iconMarkup),iconPaths:Object.fromEntries(Object.keys(iconMarkup).map(id=>[id,path.join(ASSET_ROOT,id+'.png')]))};

