/* Skin only: no game logic; original map outline/object/price locations stay fixed. */
const K=require('../native_components/common.cjs');
const palette={yellow:[220,190,112],green:[154,187,117],purple:[177,146,196],blue:[111,177,199],pink:[222,143,163],orange:[231,164,119]};
const names=Object.keys(palette);
function family(r,g,b){
 // Neutral unowned sand is warm cream, never yellow ownership.
 if(r>220&&g>210&&b>190)return -1;
 const hi=Math.max(r,g,b),lo=Math.min(r,g,b),s=hi?1-lo/hi:0;
 if(hi<190||s<.10||s>.64)return -1;
 const d=hi-lo;let h=hi===r?((g-b)/d)%6:hi===g?(b-r)/d+2:(r-g)/d+4;h*=60;if(h<0)h+=360;
 return h>=38&&h<61?0:h>=61&&h<155?1:h>=225&&h<318?2:h>=155&&h<225?3:h>=318||h<10?4:5;
}
function protectedPixel(x,y,modal){return y<140||y>=1128||(x>=610&&x<673&&y<174)||(modal&&x>=60&&x<660&&y>=176&&y<1000);}
async function styleWorld(ctx,{modal=false,lobby}={}){
 const W=720,H=1280,im=ctx.getImageData(0,0,W,H),d=im.data,N=W*H,original=new Uint8ClampedArray(d);
 const labels=new Int8Array(N).fill(-1),seen=new Uint8Array(N),queue=new Int32Array(N),bg=new Uint8Array(N);
 for(let y=140;y<1128;y++)for(let x=0;x<W;x++){if(protectedPixel(x,y,modal))continue;const i=y*W+x,p=i*4;labels[i]=family(d[p],d[p+1],d[p+2]);if(Math.abs(d[p]-244)<=3&&Math.abs(d[p+1]-238)<=3&&Math.abs(d[p+2]-227)<=3)bg[i]=1;}
 const stats={field_components:[],field_pixels:0,outside_forest_pixels:0,building_materials:[],geometry:'No polygon generation, object movement or price changes; only detected large field fills, edge-connected outside blank pixels and eroded building-silhouette interiors are recolored.'};
 for(let start=140*W;start<1128*W;start++){
  const cls=labels[start];if(cls<0||seen[start])continue;let a=0,b=0,minx=999,miny=999,maxx=0,maxy=0;queue[b++]=start;seen[start]=1;
  while(a<b){const i=queue[a++],x=i%W,y=(i/W)|0;minx=Math.min(minx,x);maxx=Math.max(maxx,x);miny=Math.min(miny,y);maxy=Math.max(maxy,y);for(const j of [x?i-1:-1,x<W-1?i+1:-1,i-W,i+W]){if(j<0||j>=N||seen[j]||labels[j]!==cls)continue;seen[j]=1;queue[b++]=j;}}
  if(b<1000||maxx-minx<42||maxy-miny<36)continue;
  const pcol=palette[names[cls]];for(let n=0;n<b;n++){const p=queue[n]*4;d[p]=pcol[0];d[p+1]=pcol[1];d[p+2]=pcol[2];}stats.field_pixels+=b;stats.field_components.push({family:names[cls],rect:[minx,miny,maxx-minx+1,maxy-miny+1],pixels:b});
 }
 if(lobby){
  // Same paper color is used both outside the map and in the grid seams.
  // Preserve every seam/outer outline: blank pixels near a field stay cream.
  const nearby=new Uint8Array(N);
  for(let y=140;y<1128;y++)for(let x=0;x<W;x++){const i=y*W+x,p=i*4,hi=Math.max(d[p],d[p+1],d[p+2]),lo=Math.min(d[p],d[p+1],d[p+2]);if(hi<180||(hi-lo)/hi<.08)continue;for(let dy=-4;dy<=4;dy++){const yy=y+dy;if(yy<140||yy>=1128)continue;for(let dx=-4;dx<=4;dx++){const xx=x+dx;if(xx>=0&&xx<W)nearby[yy*W+xx]=1;}}}
  for(let i=140*W;i<1128*W;i++)if(bg[i]&&nearby[i]){bg[i]=0;const p=i*4;d[p]=243;d[p+1]=233;d[p+2]=210;}
  const source=await K.loadImage(lobby),forest=K.createCanvas(W,H),fc=forest.getContext('2d');fc.fillStyle='#47774e';fc.fillRect(0,0,W,H);
  // One broad original forest band above the castle's flag. Never tile a log/tree crop.
  const sx=source.width/941,sy=source.height/1672;
  fc.drawImage(source,65*sx,180*sy,810*sx,125*sy,0,140,720,230);
  stats.forest_source_crop=[65,180,810,125];stats.forest_draw_count=1;
  fc.fillStyle='rgba(25,63,41,.16)';fc.fillRect(0,0,W,H);const f=fc.getImageData(0,0,W,H).data;
  seen.fill(0);let a=0,b=0;const seed=i=>{if(bg[i]&&!seen[i]){seen[i]=1;queue[b++]=i;}};
  for(let y=140;y<1128;y++){seed(y*W);seed(y*W+719);}for(let x=0;x<W;x++){seed(140*W+x);seed(1127*W+x);}
  while(a<b){const i=queue[a++],x=i%W,p=i*4;d[p]=f[p];d[p+1]=f[p+1];d[p+2]=f[p+2];stats.outside_forest_pixels++;for(const j of [x?i-1:-1,x<W-1?i+1:-1,i-W,i+W]){if(j<0||j>=N||seen[j]||!bg[j])continue;seen[j]=1;queue[b++]=j;}}
 }
 // Locked site art stays unidentified: retain its exact silhouette and outer rim.
 // Fill only the large connected dark interiors, avoiding glyphs, prices and coin rings.
 const dark=new Uint8Array(N);seen.fill(0);
 for(let y=140;y<1128;y++)for(let x=0;x<W;x++){if(protectedPixel(x,y,modal))continue;const i=y*W+x,p=i*4;if(original[p]<92&&original[p+1]<92&&original[p+2]<106)dark[i]=1;}
 for(let start=140*W;start<1128*W;start++){
  if(!dark[start]||seen[start])continue;let a=0,b=0,minx=999,miny=999,maxx=0,maxy=0;queue[b++]=start;seen[start]=1;
  while(a<b){const i=queue[a++],x=i%W,y=(i/W)|0;minx=Math.min(minx,x);maxx=Math.max(maxx,x);miny=Math.min(miny,y);maxy=Math.max(maxy,y);for(const j of[x?i-1:-1,x<W-1?i+1:-1,i-W,i+W]){if(j<0||j>=N||seen[j]||!dark[j])continue;seen[j]=1;queue[b++]=j;}}
  const w=maxx-minx+1,h=maxy-miny+1;if(w<38||h<26||w>125||h>130||b<500)continue;
  const inside=[];
  for(let n=0;n<b;n++){const i=queue[n],x=i%W,y=(i/W)|0;let rim=false;for(let dy=-3;dy<=3&&!rim;dy++)for(let dx=-3;dx<=3;dx++){if(Math.abs(dx)+Math.abs(dy)>3)continue;const xx=x+dx,yy=y+dy;if(xx<0||xx>=W||yy<0||yy>=H||!dark[yy*W+xx]){rim=true;break;}}if(!rim)inside.push(i);}
  if(inside.length<240)continue;
  const topY=Math.min(maxy,miny+Math.floor(h*.33));let segments=0,on=false;
  for(let x=minx;x<=maxx;x++){const yes=!!dark[topY*W+x];if(yes&&!on)segments++;on=yes;}
  const mineral=segments>=2,tower=h>w*1.15;
  for(const i of inside){const x=i%W,y=(i/W)|0,u=(x-minx)/w,v=(y-miny)/h;let c;
   if(mineral||tower)c=u<.48?[85,99,106]:[56,71,81];
   else if(v<.48)c=u<.5?[64,79,89]:[42,57,69];
   else c=u<.52?[113,87,61]:[85,67,51];
   // Restrained broad seams retain a readable two-tone matte surface at native size.
   if(!mineral&&!tower&&v>=.48&&Math.abs(((y-miny)%13)-1)<=1)c=c.map(v=>Math.max(0,v-12));
   const p=i*4;d[p]=c[0];d[p+1]=c[1];d[p+2]=c[2];
  }
  stats.building_materials.push({rect:[minx,miny,w,h],interior_pixels:inside.length,outer_rim_preserved_px:3,material:mineral?'split_stone':tower?'dark_stone':'dark_timber_and_slate'});
 }
 ctx.putImageData(im,0,0);return stats;
}
module.exports={palette,styleWorld};
