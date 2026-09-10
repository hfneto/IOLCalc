const DEFOCUS_X = [1.0,0.5,0.0,-0.5,-1.0,-1.5,-2.0,-2.5,-3.0]; // dioptrias de defocus
/* ============================================================
   MOTOR DE FÓRMULAS (validado contra valores de referência)
   ============================================================ */
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
function holladay1(AL,K,A,R){
  const SF=0.5663*A-65.6;
  const r=337.5/K;
  const AG=Math.min(13.5,12.5*AL/23.45);
  let disc=r*r-(AG*AG)/4; if(disc<0)disc=0;
  const aACD=0.56+r-Math.sqrt(disc);
  const ELP=aACD+SF;
  const L=AL+0.2;
  const Kc=1000*(1/3)/r;
  const Rx=toCornealPlane(R);
  const V1=Kc+Rx;
  return (1336/(L-ELP))-(1336/(1336/V1-ELP));
}
function pACDfromA(A){return 0.58357*A-63.896;}
function hofferQ(AL,K,A,R){
  const pACD=pACDfromA(A);
  let ALc=Math.min(31,Math.max(18.5,AL));
  const M=ALc<=23?1:-1;
  const G=ALc<=23?28:23.5;
  const tanK=Math.tan(K*Math.PI/180);
  const ACD=pACD+0.3*(ALc-23.5)+tanK*tanK
    +(0.1*M*Math.pow(23.5-ALc,2)*Math.tan(0.1*Math.pow(G-ALc,2)*Math.PI/180))
    -0.99166;
  const Rx=toCornealPlane(R);
  return (1336/(AL-ACD-0.05))-(1.336/((1.336/(K+Rx))-((ACD+0.05)/1000)));
}
// T2 (Sheard, Smith & Cooke 2010): SRK/T com a altura corneana H substituída pela
// regressão H2 = -10.326 + 0.32630·AL + 0.13533·K (AL SEM correção — evita o "cusp" do SRK/T)
function t2(AL,K,A,R){
  const H=-10.326+0.32630*AL+0.13533*K;
  const ACD=(0.62467*A-68.747)-3.336+H;
  const L=AL+(0.65696-0.02029*AL);
  const r=337.5/K;
  const Rx=toCornealPlane(R);
  const Kc=1000*0.333/r;
  const V1=Kc+Rx;
  return (1336/(L-ACD))-(1336/(1336/V1-ACD));
}
// Wang-Koch modificado (2018) p/ Holladay 1: AL ajustado = 0.817·AL + 4.7013 quando AL > 26 mm
const WK_THRESHOLD=26;
function wkAL(AL){return 0.817*AL+4.7013;}
function holladay1WK(AL,K,A,R){return holladay1(AL>WK_THRESHOLD?wkAL(AL):AL,K,A,R);}
// Castrop (Langenbucher 2021, PLoS ONE): vergência com córnea espessa (2 superfícies) e LIO fina.
// nC=1.376, CCT=0.5 mm, razão posterior/anterior de Liou-Brennan (6.40/7.77), índice ceratométrico 1.3375.
// ELP = ACD + C·LT + H (do vértice corneano). C=0.424 e R=0.077 do paper; H calibrado por constante A.
const CASTROP={C:0.424,R:0.077,nC:1.376,n:1.336,CCT:0.5,LB:6.40/7.77};
function castropRaw(AL,K,H,Rtarget,ACDpre,LT){
  const ACD=(ACDpre==null||isNaN(ACDpre)||ACDpre<=0)?3.37:ACDpre;
  const LTu=(LT==null||isNaN(LT)||LT<=0)?4.7:LT;
  const rca=337.5/K;                          // raio anterior (mm) do K ceratométrico
  const Pca=(CASTROP.nC-1)*1000/rca;
  const rcp=rca*CASTROP.LB;
  const Pcp=(CASTROP.n-CASTROP.nC)*1000/rcp;
  const ELP=ACD+CASTROP.C*LTu+H;
  const Rc=toCornealPlane(Rtarget-CASTROP.R); // alvo no plano corneano, já descontando o offset R
  let V=Rc+Pca;                               // vergência após a face anterior
  V=V/(1-(CASTROP.CCT/CASTROP.nC/1000)*V);    // propaga a espessura corneana
  V=V+Pcp;                                    // face posterior
  V=V/(1-((ELP-CASTROP.CCT)/CASTROP.n/1000)*V); // propaga até o plano da LIO
  return 1000*CASTROP.n/(AL-ELP)-V;
}
const _calCache={};
function calibrate(key,calcFn){ // memoiza calibrações por constante A (bisseção é cara)
  if(_calCache[key]==null)_calCache[key]=calcFn();
  return _calCache[key];
}
// calibra o H da Castrop p/ casar o SRK/T no olho padrão (AL 23.5, K 43.5, ACD 3.37, LT 4.7)
function castropH(A){
  return calibrate('castrop_'+A,()=>{
    const target=srkt(23.5,43.5,A,0);
    let lo=-4,hi=4;
    for(let i=0;i<60;i++){const mid=(lo+hi)/2;const p=castropRaw(23.5,43.5,mid,0,3.37,4.7);if(p>target)hi=mid;else lo=mid;}
    return (lo+hi)/2;
  });
}
function castrop(AL,K,A,R,ACDpre,LT){return castropRaw(AL,K,castropH(A),R,ACDpre,LT);}
// Haigis: a1=0.4, a2=0.1 fixos; a0 calibrado por bisseção para casar a PREDIÇÃO do SRK/T
// no olho padrão. NÃO usar a conversão "padrão" a0=0.62467·A−72.434: ela iguala a ELP mas
// ignora as convenções próprias do Haigis (índice corneano 1.3315 e AL sem correção retiniana),
// gerando +1.3 D sistemático vs as demais fórmulas (verificado em 08/2026).
function haigisA0(A){
  // calibra a0 para que olho padrão (AL23.5,K43.5,ACD3.37) ~ SRK/T
  return calibrate('haigis_'+A,()=>{
  const target=srkt(23.5,43.5,A,0);
  let lo=-3,hi=5;
  for(let i=0;i<60;i++){const mid=(lo+hi)/2;const p=haigisRaw(23.5,43.5,{a0:mid,a1:0.4,a2:0.1},0,3.37);if(p<target)lo=mid;else hi=mid;}
  return (lo+hi)/2;
  });
}
function haigisRaw(AL,K,c,R,ACDpre){
  const{a0,a1,a2}=c;
  const ACDuse=(ACDpre==null||isNaN(ACDpre)||ACDpre<=0)?3.37:ACDpre;
  const d=a0+a1*ACDuse+a2*AL;
  const r=337.5/K;
  const DC=(1.3315-1)*1000/r;
  const Rx=toCornealPlane(R);
  const z=DC+Rx; const n=1.336;
  return (1000*n/(AL-d))-(1000*n/(1000*n/z-d));
}
function haigis(AL,K,A,R,ACDpre){
  return haigisRaw(AL,K,{a0:haigisA0(A),a1:0.4,a2:0.1},R,ACDpre);
}
// refração prevista para um poder P implantado (inversão por bisseção)
function predRefraction(fn,AL,K,A,P,ACD,LT){
  let lo=-20,hi=20;
  for(let i=0;i<60;i++){const mid=(lo+hi)/2;const p=fn(AL,K,A,mid,ACD,LT);if(p>P)lo=mid;else hi=mid;}
  return (lo+hi)/2;
}
const FORMULAS=[
 {key:'SRK/T',fn:(AL,K,A,R,ACD,LT)=>srkt(AL,K,A,R)},
 {key:'T2',fn:(AL,K,A,R,ACD,LT)=>t2(AL,K,A,R)},
 {key:'Holladay 1',fn:(AL,K,A,R,ACD,LT)=>holladay1(AL,K,A,R)},
 {key:'Holladay 1 WK',fn:(AL,K,A,R,ACD,LT)=>holladay1WK(AL,K,A,R),onlyIf:AL=>AL>WK_THRESHOLD},
 {key:'Hoffer Q',fn:(AL,K,A,R,ACD,LT)=>hofferQ(AL,K,A,R)},
 {key:'Haigis',fn:(AL,K,A,R,ACD,LT)=>haigis(AL,K,A,R,ACD)},
 {key:'Castrop',fn:(AL,K,A,R,ACD,LT)=>castrop(AL,K,A,R,ACD,LT)}
];
function activeFormulas(AL){return FORMULAS.filter(F=>!F.onlyIf||F.onlyIf(AL));}
function recommendedFormulas(AL){
  if(AL<22) return ['Hoffer Q','Haigis','Castrop'];
  if(AL>26) return ['Holladay 1 WK','T2','Haigis','Castrop'];
  return ['SRK/T','T2','Holladay 1','Hoffer Q','Haigis','Castrop'];
}

/* ============================================================
   DEFOCUS / BINOCULAR / ESTEREOPSIA  (porte fiel do app antigo)
   ============================================================ */
// eixo de plotagem mais fino e estendido (catálogo continua medido em DEFOCUS_X; além de -3.0 é extrapolação)
const PLOT_X=[];for(let d=1.0;d>=-4.0-1e-9;d-=0.25)PLOT_X.push(+d.toFixed(2));
const EXTRAP_FROM=-3.0;
// amostra a curva de um catálogo em qualquer defocus t (interp. linear; extrapolação linear limitada)
function sampleCurve(values,t){
  const n=DEFOCUS_X.length-1;
  let v;
  if(t>=DEFOCUS_X[0]) v=values[0]+(values[0]-values[1])*(t-DEFOCUS_X[0])/(DEFOCUS_X[0]-DEFOCUS_X[1]);
  else if(t<=DEFOCUS_X[n]) v=values[n]+(values[n]-values[n-1])*(t-DEFOCUS_X[n])/(DEFOCUS_X[n]-DEFOCUS_X[n-1]);
  else{
    for(let j=0;j<n;j++){
      if(t<=DEFOCUS_X[j]&&t>=DEFOCUS_X[j+1]){
        const f=(t-DEFOCUS_X[j])/(DEFOCUS_X[j+1]-DEFOCUS_X[j]);
        v=values[j]+f*(values[j+1]-values[j]);break;
      }
    }
  }
  return Math.max(-0.15,Math.min(0.85,v));
}
// IMPORTANTE: as curvas do catálogo (lens.values) são o resultado BINOCULAR dos estudos
// dos fabricantes. Portanto:
//  - AV MONOCULAR (um olho) = curva binocular + penalidade de somação (o olho isolado é pior).
//  - AV BINOCULAR do paciente = combinação das duas curvas monoculares; com olhos simétricos
//    ela reproduz exatamente a curva publicada (nunca melhor que ela).
// astigCyl (D) = cilindro residual não corrigido: adiciona penalidade ~constante de AV.
const SUMMATION_LOGMAR=0.07; // ganho binocular (~1 linha) em olhos simétricos
function astigPenalty(cyl){ return (!cyl||cyl<=0)?0:Math.min(0.60,0.16*cyl); }
// AV monocular no defocus d (0 = longe) com residual esférico e cilindro residual aplicados
function vaMono(lens,residual,d,cyl){
  return Math.min(0.95,sampleCurve(lens.values,d-residual)+SUMMATION_LOGMAR+astigPenalty(cyl));
}
// somação binocular: subtrai o mesmo SUMMATION quando os olhos são iguais (recupera a curva
// publicada); o ganho decai com anisometropia e some com diferença >0,30 logMAR
function binoCombine(a,b){
  const diff=Math.abs(a-b);
  const bonus=SUMMATION_LOGMAR*Math.max(0,1-diff/0.30);
  return Math.max(-0.20,Math.min(a,b)-bonus);
}
function logmarToSnellen(l){const d=Math.round(20/Math.pow(10,-l));return '20/'+d;}
function logmarToJaeger(l){
  const T=[[0.04,'J1+'],[0.13,'J1'],[0.21,'J2'],[0.34,'J3'],[0.44,'J5'],[0.52,'J7'],[0.62,'J10'],[0.72,'J11'],[0.85,'J16']];
  for(const [lim,j] of T) if(l<=lim) return j;
  return '>J16';
}
function stereoBase(a,b){
  const mono=c=>c==='monofocal'||c==='enhanced-monofocal';
  const edof=c=>c==='edof';
  const tri=c=>c==='trifocal'||c==='continuous'||c==='bifocal'; // bifocal: mesma classe multifocal p/ estereopsia
  if(mono(a)&&mono(b))return 40;
  if(edof(a)&&edof(b))return 50;
  if(tri(a)&&tri(b))return 65;
  if((mono(a)&&edof(b))||(edof(a)&&mono(b)))return 55;
  if((mono(a)&&tri(b))||(tri(a)&&mono(b)))return 85;
  return 75; // edof+tri
}
function stereoAniso(d){
  if(d<0.25)return 40; if(d<=0.50)return 60; if(d<=0.75)return 90;
  if(d<=1.0)return 140; if(d<=1.5)return 250; return 400;
}
function computeStereo(catA,catB,seA,seB){
  const base=stereoBase(catA,catB);
  const aniso=stereoAniso(Math.abs(seA-seB));
  const main=Math.max(base,aniso), minor=Math.min(base,aniso);
  return Math.round(main+(minor-40)*0.3);
}
function formatStereo(s){return s>=400?'≥400″ (limitada)':s+'″';}
const EYES=[[23.5,43.5,3.37,4.7],[21.0,46.0,2.80,4.9],[27.5,42.0,3.60,4.4],[30.0,43.0,3.80,4.2],[24.8,44.25,3.1,4.5],[22.3,45.5,2.95,4.8]];
const out={eyes:[],castropH:{},haigisA0:{},sample:[],bino:[]};
for(const A of [118.0,118.5,119.0,119.3,119.5]){out.castropH[A]=castropH(A);out.haigisA0[A]=haigisA0(A);}
for(const [AL,K,ACD,LT] of EYES){for(const A of [118.0,119.0,119.5])for(const R of [0,-0.5,-2.0]){const row={AL,K,ACD,LT,A,R,p:{}};for(const F of activeFormulas(AL))row.p[F.key]=F.fn(AL,K,A,R,ACD,LT);row.pred=predRefraction((a,k,c,r)=>srkt(a,k,c,r),AL,K,A,20.5);out.eyes.push(row);}}
const vals=[0.18,0.05,-0.04,0.03,0.13,0.24,0.38,0.52,0.65];
for(const t of [1.5,1.0,0.75,0.0,-0.3,-1.25,-3.0,-3.5,-4.0])out.sample.push([t,sampleCurve(vals,t),vaMono({values:vals},-0.25,t,0.75)]);
for(const [a,b] of [[0.1,0.1],[0.1,0.3],[0.0,0.5],[-0.1,0.05]])out.bino.push([a,b,binoCombine(a,b)]);
out.stereo=[computeStereo('monofocal','monofocal',0,0),computeStereo('edof','trifocal',-0.5,0.4),computeStereo('monofocal','trifocal',0,-1.6)];
out.jaeger=[0.0,0.13,0.3,0.5,0.9].map(logmarToJaeger);
print(JSON.stringify(out));
