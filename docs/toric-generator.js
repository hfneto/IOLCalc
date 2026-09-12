// Gera Tests/IOLCoreTests/Resources/toric.json com o JavaScript original do módulo tórico
// (funções copiadas literalmente do index.html). Rodar com o jsc do macOS:
//   /System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc docs/toric-generator.js > IOLCore/Tests/IOLCoreTests/Resources/toric.json
const VERTEX=12;
const toCornealPlane=R=>R/(1-0.001*VERTEX*R);
function srkt(AL,K,A,R){
  const ncm1=0.333; const r=337.5/K;
  const LCOR=AL>24.2?(-3.446+1.715*AL-0.0237*AL*AL):AL;
  const Cw=-5.41+0.58412*LCOR+0.098*K;
  let disc=r*r-(Cw*Cw)/4; if(disc<0)disc=0;
  const H=r-Math.sqrt(disc);
  const ACD=(0.62467*A-68.747)-3.336+H;
  const L=AL+(0.65696-0.02029*AL);
  const Rx=toCornealPlane(R);
  const Kc=1000*ncm1/r;
  const V1=Kc+Rx;
  return (1336/(L-ACD))-(1336/(1336/V1-ACD));
}
function predRefraction(fn,AL,K,A,P,ACD,LT){
  let lo=-20,hi=20;
  for(let i=0;i<60;i++){const mid=(lo+hi)/2;const p=fn(AL,K,A,mid,ACD,LT);if(p>P)lo=mid;else hi=mid;}
  return (lo+hi)/2;
}
/* ---- módulo tórico (index.html) ---- */
const TOR_D2R=Math.PI/180;
function aVec(mag,axisDeg){const a=2*axisDeg*TOR_D2R;return {x:mag*Math.cos(a),y:mag*Math.sin(a)};}
function akAdjust(v){return {x:0.508+0.926*v.x, y:0.009+0.932*v.y};}
function vAstig(v){const mag=Math.hypot(v.x,v.y);let ax=0.5*Math.atan2(v.y,v.x)/TOR_D2R;ax=((ax%180)+180)%180;return {mag,axis:ax};}
const vAdd=(...vs)=>vs.reduce((a,v)=>({x:a.x+v.x,y:a.y+v.y}),{x:0,y:0});
const vSub=(a,b)=>({x:a.x-b.x,y:a.y-b.y});
const TOR_PLATFORMS=[
  {id:'alcon',name:'Alcon Clareon/AcrySof (T2–T9)',ratio:1.46,steps:[1.00,1.50,2.25,3.00,3.75,4.50,5.25,6.00]},
  {id:'hoya',name:'HOYA Vivinex Toric (T2–T9)',ratio:1.45,steps:[1.00,1.50,2.25,3.00,3.75,4.50,5.25,6.00]},
  {id:'jj',name:'J&J Tecnis Toric',ratio:1.46,steps:[1.00,1.50,2.00,2.75,3.25,4.00]},
  {id:'zeiss',name:'Zeiss AT TORBI (0,5)',ratio:1.37,steps:Array.from({length:23},(_,i)=>+(1.0+i*0.5).toFixed(2))},
  {id:'rayner',name:'Rayner (0,5)',ratio:1.46,steps:Array.from({length:21},(_,i)=>+(1.0+i*0.5).toFixed(2))},
  {id:'generic',name:'Genérico (0,25)',ratio:1.46,steps:Array.from({length:24},(_,i)=>+(0.75+i*0.25).toFixed(2))}
];
// torState/toricRecalc com entradas explícitas em vez do DOM (mesma aritmética)
function torState(i){
  const mode=i.mode;
  const k1=i.k1==null?null:i.k1,k2=i.k2==null?null:i.k2,kax=i.kaxis==null?90:i.kaxis;
  const sia=Math.max(0,i.sia==null?0:i.sia),siaAx=i.siaAxis==null?180:i.siaAxis;
  let TCA;
  if(mode==='total'){TCA=aVec(Math.max(0,i.tkcyl==null?0:i.tkcyl),i.tkaxis==null?90:i.tkaxis);}
  else{
    const cyl=(k1!=null&&k2!=null)?Math.abs(k2-k1):0;
    if(mode==='post'){const nsMag=Math.max(0, 0.103 + 0.836*cyl + 0.457*Math.cos(2*kax*TOR_D2R));TCA=aVec(nsMag,kax);}
    else if(mode==='ak'){ TCA=akAdjust(aVec(cyl,kax)); }
    else { TCA=aVec(cyl,kax); }
  }
  TCA=vAdd(TCA,aVec(sia,siaAx+90));
  return {TCA,ta:vAstig(TCA),sia,siaAx,align:i.align==null?90:i.align,iolCyl:Math.max(0,i.iolcyl==null?0:i.iolcyl),ratio:Math.max(0.5,i.ratio==null?1.46:i.ratio),mode};
}
function toricRecalc(i){
  const st=torState(i);
  const cc=st.iolCyl/st.ratio;
  const res=vAstig(vSub(st.TCA,aVec(cc,st.align)));
  const resAligned=Math.abs(st.ta.mag-cc);
  const mis=Math.abs(((st.align-st.ta.axis+90+180)%180)-90);
  const lost=Math.round(mis*3.3);
  const sugg={};
  for(const p of TOR_PLATFORMS){const need=st.ta.mag*st.ratio;let best=p.steps[0];p.steps.forEach(s=>{if(Math.abs(s-need)<Math.abs(best-need))best=s;});sugg[p.id]=[best,Math.round(st.ta.axis)];}
  return {taMag:st.ta.mag,taAxis:st.ta.axis,cc,resMag:res.mag,resAxis:res.axis,resAligned,mis,lost,sugg};
}
function computeToricityRatio(AL,Km,Aeff,roundP,iolcyl){
  const dc=Math.max(1.0,iolcyl||2.25);
  const r1=predRefraction(srkt,AL,Km,Aeff,roundP-dc/2);
  const r2=predRefraction(srkt,AL,Km,Aeff,roundP+dc/2);
  const cylCorneal=Math.abs(toCornealPlane(r1)-toCornealPlane(r2));
  if(!(cylCorneal>0.05))return null;
  const ratio=dc/cylCorneal;
  return (ratio>=1.0&&ratio<=2.2)?ratio:null;
}
const cases=[];
const K=[[43.25,44.10,92],[42.0,44.5,180],[43.0,45.6,45],[44.2,44.3,10],[41.9,44.9,135],[43.5,43.5,90]];
for(const mode of ['ant','ak','post','total'])
  for(const [k1,k2,kax] of K)
    for(const [sia,siaAx] of [[0.10,180],[0.30,120],[0,0]])
      for(const [iolcyl,align,ratio] of [[0,90,1.46],[1.5,92,1.46],[2.25,88,1.37],[3.0,45,1.62],[1.0,0,0.4]]){
        const inp={mode,k1,k2,kaxis:kax,tkcyl:Math.abs(k2-k1)+0.35,tkaxis:(kax+7)%180,sia,siaAxis:siaAx,iolcyl,align,ratio};
        cases.push({input:inp,out:toricRecalc(inp)});
      }
// sem K1/K2 (cilindro anterior = 0) e com defaults
cases.push({input:{mode:'ak'},out:toricRecalc({mode:'ak'})});
cases.push({input:{mode:'ant',k1:43,k2:null,iolcyl:-1,sia:-0.5,ratio:0.1},out:toricRecalc({mode:'ant',k1:43,k2:null,iolcyl:-1,sia:-0.5,ratio:0.1})});
const ratios=[];
for(const [AL,Km,A,P,cyl] of [[23.62,43.675,119.1,20.5,0],[23.62,43.675,119.1,20.5,3.0],[21.0,46.0,118.0,27.5,1.5],[27.5,42.0,119.5,11.0,0],[30.0,43.0,119.0,3.5,6.0],[23.5,43.5,119.0,21.5,0.5]])
  ratios.push({AL,Km,A,P,cyl,ratio:computeToricityRatio(AL,Km,A,P,cyl)});
const ak=[[1.0,90],[1.0,180],[0,90],[2.5,45],[0.8,135]].map(([m,a])=>{const v=vAstig(akAdjust(aVec(m,a)));return [m,a,v.mag,v.axis];});
print(JSON.stringify({cases,ratios,ak}));
