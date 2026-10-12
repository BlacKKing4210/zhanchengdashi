/* Offline PNG navigation only. This does not implement game actions. */
(() => {
 const picture=document.querySelector('#viewer-image'),stage=document.querySelector('#image-stage'),space=document.querySelector('.image-space');
 const recent=document.querySelector('#hotspot-recent'),close=document.querySelector('#hotspot-history-close'),back=document.querySelector('#hotspot-history-return');
 let returnView=null;
 const rects={recent:[508,142,184,54],close:[601,242,48,48],back:[160,958,400,60]};
 function locate(button,r){button.style.left=r[0]/720*100+'%';button.style.top=r[1]/1280*100+'%';button.style.width=r[2]/720*100+'%';button.style.height=r[3]/1280*100+'%';}
 locate(recent,rects.recent);locate(close,rects.close);locate(back,rects.back);
 function view(){return views.find(v=>v.file===picture.getAttribute('src'));}
 function fit(){
  const v=view();if(!dialog.open||!v)return;
  const w=Math.max(1,space.clientWidth-24),h=Math.max(1,space.clientHeight-24),s=Math.min(w/v.width,h/v.height);
  stage.style.width=v.width*s+'px';stage.style.height=v.height*s+'px';
  const main=v.id==='gacha-empty',history=v.id==='gacha-history';recent.hidden=!main;close.hidden=!history;back.hidden=!history;
 }
 function paint(v){
  picture.src=v.file;picture.alt=v.title;document.querySelector('#viewer-title').textContent=v.title;
  document.querySelector('#viewer-description').textContent=v.id==='gacha-history'?'点击画面中的关闭或返回招募，可回到宣传画。这里仅切换效果图。':v.description;
  document.querySelector('#viewer-size').textContent=v.width+' × '+v.height+' · PNG 交互效果预览';document.querySelector('#viewer-save').href=v.file;requestAnimationFrame(fit);
 }
 function enter(e){e.preventDefault();e.stopPropagation();returnView=view();paint(views.find(v=>v.id==='gacha-history'));}
 function leave(e){e.preventDefault();e.stopPropagation();paint(returnView||views.find(v=>v.id==='gacha-empty'));returnView=null;}
 recent.addEventListener('click',enter);close.addEventListener('click',leave);back.addEventListener('click',leave);
 recent.hidden=close.hidden=back.hidden=true;
 picture.addEventListener('load',()=>requestAnimationFrame(fit));new ResizeObserver(fit).observe(space);
 const originalShow=show;show=function(index){returnView=null;originalShow(index);requestAnimationFrame(fit);};
 document.querySelectorAll('[data-open]').forEach(b=>b.addEventListener('click',()=>requestAnimationFrame(fit)));
 window.addEventListener('resize',()=>requestAnimationFrame(fit));
})();
