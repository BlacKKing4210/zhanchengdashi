'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/AI/zhanchengdashi';
const DATA = JSON.parse(fs.readFileSync(path.join(__dirname, 'native-scene-data.json'), 'utf8'));
function cardRect(index) {
  let row=0, col=index;
  const counts=DATA.geometry.ten_row_counts, [cw,ch]=DATA.geometry.ten_card_size, [gx,gy]=DATA.geometry.ten_gap;
  while (col>=counts[row]) {col-=counts[row]; row++;}
  const rowWidth=counts[row]*cw+(counts[row]-1)*gx;
  let x=(720-rowWidth)*0.5;
  if(row===1)x-=12;
  if(row===2)x+=12;
  const groupHeight=counts.length*ch+(counts.length-1)*gy;
  const y=298+(716-groupHeight)*0.5;
  return [x+col*(cw+gx),y+row*(ch+gy),cw,ch];
}
function loadFormalCards(){
  const rows=JSON.parse(fs.readFileSync(path.join(ROOT,'runtime/config/cards.json'),'utf8'));
  return Object.fromEntries(rows.filter(r=>r&&r.id&&r.art_path).map(r=>[r.id,{...r,local_art_path:path.join(ROOT,r.art_path.replace(/^res:\/\//,''))}]));
}
module.exports={ROOT,DATA,cardRect,loadFormalCards};

