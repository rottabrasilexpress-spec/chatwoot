import{c as O,r as Q,w as Jt,ae as En,a9 as yn,H as Tn,o as In,e as bn,g as Rn,k as $n,B as Nt,F as xn}from"./_plugin-vue_export-helper-PM2umi06.js";import{U as kn,u as oe,e as H,b as G,c as vt}from"./useBranding-kyg_bZSt.js";import{a as Ct}from"./index-DghbQm9C.js";import{P as jn,Q as ft,R as qt,S as Qt,T as Dn,U as Bn,V as Ln,W as Hn,X as Pn,Y as Zn,Z as en,$ as tn,a0 as Vn,a1 as Un,a2 as Gn,a3 as Kn,a4 as zn,a5 as rt,a6 as Fn,a7 as Yn,a8 as Wn,a9 as Xn,aa as Jn}from"./dashboard-CVfJQSI-.js";import{L as qn,u as gt,w as z,a as Qn}from"./Validators-SUyUGvBq.js";import{L as ei,O as ti,F as ni,bT as ii,bU as oi}from"./DashboardIcon-Co_PKxMA.js";import"./utils.esm-DY_uR2pP.js";import"./_commonjsHelpers-gnU0ypJ3.js";import"./index-DfObaZVU.js";import"./index-DPTuQ6cd.js";import"./index-DN3rM4CW.js";import"./typing-CXiSp9nA.js";import"./index-BDPgcbsG.js";import"./vue-dompurify-html-DrFQMDmR.js";import"./useKeyboardNavigableList-CRxqLAWc.js";import"./helper-BVTgYTlr.js";import"./Icon-BfTLB-HL.js";import"./index-CjF4XmwS.js";import"./module-DB3vovU6.js";import"./chatwoot-viz-D2FRxUay.js";import"./index-DfsDTqrj.js";import"./constants-lVAyZKq6.js";import"./IframeLoader-ZWCDA7FT.js";import"./HTMLSanitizer-cciupgGC.js";import"./js.cookie-Cz0CWeBA.js";/**
 * @license
 * Copyright 2019 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Te=window,Ot=Te.ShadowRoot&&(Te.ShadyCSS===void 0||Te.ShadyCSS.nativeShadow)&&"adoptedStyleSheets"in Document.prototype&&"replace"in CSSStyleSheet.prototype,At=Symbol(),Mt=new WeakMap;let nn=class{constructor(e,t,i){if(this._$cssResult$=!0,i!==At)throw Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");this.cssText=e,this.t=t}get styleSheet(){let e=this.o;const t=this.t;if(Ot&&e===void 0){const i=t!==void 0&&t.length===1;i&&(e=Mt.get(t)),e===void 0&&((this.o=e=new CSSStyleSheet).replaceSync(this.cssText),i&&Mt.set(t,e))}return e}toString(){return this.cssText}};const si=n=>new nn(typeof n=="string"?n:n+"",void 0,At),$e=(n,...e)=>{const t=n.length===1?n[0]:e.reduce(((i,o,s)=>i+(a=>{if(a._$cssResult$===!0)return a.cssText;if(typeof a=="number")return a;throw Error("Value passed to 'css' function must be a 'css' function result: "+a+". Use 'unsafeCSS' to pass non-literal values, but take care to ensure page security.")})(o)+n[s+1]),n[0]);return new nn(t,n,At)},ai=(n,e)=>{Ot?n.adoptedStyleSheets=e.map((t=>t instanceof CSSStyleSheet?t:t.styleSheet)):e.forEach((t=>{const i=document.createElement("style"),o=Te.litNonce;o!==void 0&&i.setAttribute("nonce",o),i.textContent=t.cssText,n.appendChild(i)}))},St=Ot?n=>n:n=>n instanceof CSSStyleSheet?(e=>{let t="";for(const i of e.cssRules)t+=i.cssText;return si(t)})(n):n;/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Ke;const Ie=window,wt=Ie.trustedTypes,ri=wt?wt.emptyScript:"",Et=Ie.reactiveElementPolyfillSupport,lt={toAttribute(n,e){switch(e){case Boolean:n=n?ri:null;break;case Object:case Array:n=n==null?n:JSON.stringify(n)}return n},fromAttribute(n,e){let t=n;switch(e){case Boolean:t=n!==null;break;case Number:t=n===null?null:Number(n);break;case Object:case Array:try{t=JSON.parse(n)}catch{t=null}}return t}},on=(n,e)=>e!==n&&(e==e||n==n),ze={attribute:!0,type:String,converter:lt,reflect:!1,hasChanged:on},ct="finalized";let ae=class extends HTMLElement{constructor(){super(),this._$Ei=new Map,this.isUpdatePending=!1,this.hasUpdated=!1,this._$El=null,this._$Eu()}static addInitializer(e){var t;this.finalize(),((t=this.h)!==null&&t!==void 0?t:this.h=[]).push(e)}static get observedAttributes(){this.finalize();const e=[];return this.elementProperties.forEach(((t,i)=>{const o=this._$Ep(i,t);o!==void 0&&(this._$Ev.set(o,i),e.push(o))})),e}static createProperty(e,t=ze){if(t.state&&(t.attribute=!1),this.finalize(),this.elementProperties.set(e,t),!t.noAccessor&&!this.prototype.hasOwnProperty(e)){const i=typeof e=="symbol"?Symbol():"__"+e,o=this.getPropertyDescriptor(e,i,t);o!==void 0&&Object.defineProperty(this.prototype,e,o)}}static getPropertyDescriptor(e,t,i){return{get(){return this[t]},set(o){const s=this[e];this[t]=o,this.requestUpdate(e,s,i)},configurable:!0,enumerable:!0}}static getPropertyOptions(e){return this.elementProperties.get(e)||ze}static finalize(){if(this.hasOwnProperty(ct))return!1;this[ct]=!0;const e=Object.getPrototypeOf(this);if(e.finalize(),e.h!==void 0&&(this.h=[...e.h]),this.elementProperties=new Map(e.elementProperties),this._$Ev=new Map,this.hasOwnProperty("properties")){const t=this.properties,i=[...Object.getOwnPropertyNames(t),...Object.getOwnPropertySymbols(t)];for(const o of i)this.createProperty(o,t[o])}return this.elementStyles=this.finalizeStyles(this.styles),!0}static finalizeStyles(e){const t=[];if(Array.isArray(e)){const i=new Set(e.flat(1/0).reverse());for(const o of i)t.unshift(St(o))}else e!==void 0&&t.push(St(e));return t}static _$Ep(e,t){const i=t.attribute;return i===!1?void 0:typeof i=="string"?i:typeof e=="string"?e.toLowerCase():void 0}_$Eu(){var e;this._$E_=new Promise((t=>this.enableUpdating=t)),this._$AL=new Map,this._$Eg(),this.requestUpdate(),(e=this.constructor.h)===null||e===void 0||e.forEach((t=>t(this)))}addController(e){var t,i;((t=this._$ES)!==null&&t!==void 0?t:this._$ES=[]).push(e),this.renderRoot!==void 0&&this.isConnected&&((i=e.hostConnected)===null||i===void 0||i.call(e))}removeController(e){var t;(t=this._$ES)===null||t===void 0||t.splice(this._$ES.indexOf(e)>>>0,1)}_$Eg(){this.constructor.elementProperties.forEach(((e,t)=>{this.hasOwnProperty(t)&&(this._$Ei.set(t,this[t]),delete this[t])}))}createRenderRoot(){var e;const t=(e=this.shadowRoot)!==null&&e!==void 0?e:this.attachShadow(this.constructor.shadowRootOptions);return ai(t,this.constructor.elementStyles),t}connectedCallback(){var e;this.renderRoot===void 0&&(this.renderRoot=this.createRenderRoot()),this.enableUpdating(!0),(e=this._$ES)===null||e===void 0||e.forEach((t=>{var i;return(i=t.hostConnected)===null||i===void 0?void 0:i.call(t)}))}enableUpdating(e){}disconnectedCallback(){var e;(e=this._$ES)===null||e===void 0||e.forEach((t=>{var i;return(i=t.hostDisconnected)===null||i===void 0?void 0:i.call(t)}))}attributeChangedCallback(e,t,i){this._$AK(e,i)}_$EO(e,t,i=ze){var o;const s=this.constructor._$Ep(e,i);if(s!==void 0&&i.reflect===!0){const a=(((o=i.converter)===null||o===void 0?void 0:o.toAttribute)!==void 0?i.converter:lt).toAttribute(t,i.type);this._$El=e,a==null?this.removeAttribute(s):this.setAttribute(s,a),this._$El=null}}_$AK(e,t){var i;const o=this.constructor,s=o._$Ev.get(e);if(s!==void 0&&this._$El!==s){const a=o.getPropertyOptions(s),r=typeof a.converter=="function"?{fromAttribute:a.converter}:((i=a.converter)===null||i===void 0?void 0:i.fromAttribute)!==void 0?a.converter:lt;this._$El=s,this[s]=r.fromAttribute(t,a.type),this._$El=null}}requestUpdate(e,t,i){let o=!0;e!==void 0&&(((i=i||this.constructor.getPropertyOptions(e)).hasChanged||on)(this[e],t)?(this._$AL.has(e)||this._$AL.set(e,t),i.reflect===!0&&this._$El!==e&&(this._$EC===void 0&&(this._$EC=new Map),this._$EC.set(e,i))):o=!1),!this.isUpdatePending&&o&&(this._$E_=this._$Ej())}async _$Ej(){this.isUpdatePending=!0;try{await this._$E_}catch(t){Promise.reject(t)}const e=this.scheduleUpdate();return e!=null&&await e,!this.isUpdatePending}scheduleUpdate(){return this.performUpdate()}performUpdate(){var e;if(!this.isUpdatePending)return;this.hasUpdated,this._$Ei&&(this._$Ei.forEach(((o,s)=>this[s]=o)),this._$Ei=void 0);let t=!1;const i=this._$AL;try{t=this.shouldUpdate(i),t?(this.willUpdate(i),(e=this._$ES)===null||e===void 0||e.forEach((o=>{var s;return(s=o.hostUpdate)===null||s===void 0?void 0:s.call(o)})),this.update(i)):this._$Ek()}catch(o){throw t=!1,this._$Ek(),o}t&&this._$AE(i)}willUpdate(e){}_$AE(e){var t;(t=this._$ES)===null||t===void 0||t.forEach((i=>{var o;return(o=i.hostUpdated)===null||o===void 0?void 0:o.call(i)})),this.hasUpdated||(this.hasUpdated=!0,this.firstUpdated(e)),this.updated(e)}_$Ek(){this._$AL=new Map,this.isUpdatePending=!1}get updateComplete(){return this.getUpdateComplete()}getUpdateComplete(){return this._$E_}shouldUpdate(e){return!0}update(e){this._$EC!==void 0&&(this._$EC.forEach(((t,i)=>this._$EO(i,this[i],t))),this._$EC=void 0),this._$Ek()}updated(e){}firstUpdated(e){}};ae[ct]=!0,ae.elementProperties=new Map,ae.elementStyles=[],ae.shadowRootOptions={mode:"open"},Et==null||Et({ReactiveElement:ae}),((Ke=Ie.reactiveElementVersions)!==null&&Ke!==void 0?Ke:Ie.reactiveElementVersions=[]).push("1.6.3");/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Fe;const be=window,re=be.trustedTypes,yt=re?re.createPolicy("lit-html",{createHTML:n=>n}):void 0,ht="$lit$",K=`lit$${(Math.random()+"").slice(9)}$`,sn="?"+K,li=`<${sn}>`,te=document,ge=()=>te.createComment(""),Oe=n=>n===null||typeof n!="object"&&typeof n!="function",an=Array.isArray,ci=n=>an(n)||typeof(n==null?void 0:n[Symbol.iterator])=="function",Ye=`[ 	
\f\r]`,ue=/<(?:(!--|\/[^a-zA-Z])|(\/?[a-zA-Z][^>\s]*)|(\/?$))/g,Tt=/-->/g,It=/>/g,X=RegExp(`>|${Ye}(?:([^\\s"'>=/]+)(${Ye}*=${Ye}*(?:[^ 	
\f\r"'\`<>=]|("|')|))|$)`,"g"),bt=/'/g,Rt=/"/g,rn=/^(?:script|style|textarea|title)$/i,hi=n=>(e,...t)=>({_$litType$:n,strings:e,values:t}),I=hi(1),x=Symbol.for("lit-noChange"),N=Symbol.for("lit-nothing"),$t=new WeakMap,ee=te.createTreeWalker(te,129,null,!1);function ln(n,e){if(!Array.isArray(n)||!n.hasOwnProperty("raw"))throw Error("invalid template strings array");return yt!==void 0?yt.createHTML(e):e}const di=(n,e)=>{const t=n.length-1,i=[];let o,s=e===2?"<svg>":"",a=ue;for(let r=0;r<t;r++){const l=n[r];let c,h,d=-1,u=0;for(;u<l.length&&(a.lastIndex=u,h=a.exec(l),h!==null);)u=a.lastIndex,a===ue?h[1]==="!--"?a=Tt:h[1]!==void 0?a=It:h[2]!==void 0?(rn.test(h[2])&&(o=RegExp("</"+h[2],"g")),a=X):h[3]!==void 0&&(a=X):a===X?h[0]===">"?(a=o??ue,d=-1):h[1]===void 0?d=-2:(d=a.lastIndex-h[2].length,c=h[1],a=h[3]===void 0?X:h[3]==='"'?Rt:bt):a===Rt||a===bt?a=X:a===Tt||a===It?a=ue:(a=X,o=void 0);const p=a===X&&n[r+1].startsWith("/>")?" ":"";s+=a===ue?l+li:d>=0?(i.push(c),l.slice(0,d)+ht+l.slice(d)+K+p):l+K+(d===-2?(i.push(void 0),r):p)}return[ln(n,s+(n[t]||"<?>")+(e===2?"</svg>":"")),i]};class Ae{constructor({strings:e,_$litType$:t},i){let o;this.parts=[];let s=0,a=0;const r=e.length-1,l=this.parts,[c,h]=di(e,t);if(this.el=Ae.createElement(c,i),ee.currentNode=this.el.content,t===2){const d=this.el.content,u=d.firstChild;u.remove(),d.append(...u.childNodes)}for(;(o=ee.nextNode())!==null&&l.length<r;){if(o.nodeType===1){if(o.hasAttributes()){const d=[];for(const u of o.getAttributeNames())if(u.endsWith(ht)||u.startsWith(K)){const p=h[a++];if(d.push(u),p!==void 0){const v=o.getAttribute(p.toLowerCase()+ht).split(K),A=/([.?@])?(.*)/.exec(p);l.push({type:1,index:s,name:A[2],strings:v,ctor:A[1]==="."?pi:A[1]==="?"?vi:A[1]==="@"?fi:xe})}else l.push({type:6,index:s})}for(const u of d)o.removeAttribute(u)}if(rn.test(o.tagName)){const d=o.textContent.split(K),u=d.length-1;if(u>0){o.textContent=re?re.emptyScript:"";for(let p=0;p<u;p++)o.append(d[p],ge()),ee.nextNode(),l.push({type:2,index:++s});o.append(d[u],ge())}}}else if(o.nodeType===8)if(o.data===sn)l.push({type:2,index:s});else{let d=-1;for(;(d=o.data.indexOf(K,d+1))!==-1;)l.push({type:7,index:s}),d+=K.length-1}s++}}static createElement(e,t){const i=te.createElement("template");return i.innerHTML=e,i}}function le(n,e,t=n,i){var o,s,a,r;if(e===x)return e;let l=i!==void 0?(o=t._$Co)===null||o===void 0?void 0:o[i]:t._$Cl;const c=Oe(e)?void 0:e._$litDirective$;return(l==null?void 0:l.constructor)!==c&&((s=l==null?void 0:l._$AO)===null||s===void 0||s.call(l,!1),c===void 0?l=void 0:(l=new c(n),l._$AT(n,t,i)),i!==void 0?((a=(r=t)._$Co)!==null&&a!==void 0?a:r._$Co=[])[i]=l:t._$Cl=l),l!==void 0&&(e=le(n,l._$AS(n,e.values),l,i)),e}class ui{constructor(e,t){this._$AV=[],this._$AN=void 0,this._$AD=e,this._$AM=t}get parentNode(){return this._$AM.parentNode}get _$AU(){return this._$AM._$AU}u(e){var t;const{el:{content:i},parts:o}=this._$AD,s=((t=e==null?void 0:e.creationScope)!==null&&t!==void 0?t:te).importNode(i,!0);ee.currentNode=s;let a=ee.nextNode(),r=0,l=0,c=o[0];for(;c!==void 0;){if(r===c.index){let h;c.type===2?h=new he(a,a.nextSibling,this,e):c.type===1?h=new c.ctor(a,c.name,c.strings,this,e):c.type===6&&(h=new gi(a,this,e)),this._$AV.push(h),c=o[++l]}r!==(c==null?void 0:c.index)&&(a=ee.nextNode(),r++)}return ee.currentNode=te,s}v(e){let t=0;for(const i of this._$AV)i!==void 0&&(i.strings!==void 0?(i._$AI(e,i,t),t+=i.strings.length-2):i._$AI(e[t])),t++}}class he{constructor(e,t,i,o){var s;this.type=2,this._$AH=N,this._$AN=void 0,this._$AA=e,this._$AB=t,this._$AM=i,this.options=o,this._$Cp=(s=o==null?void 0:o.isConnected)===null||s===void 0||s}get _$AU(){var e,t;return(t=(e=this._$AM)===null||e===void 0?void 0:e._$AU)!==null&&t!==void 0?t:this._$Cp}get parentNode(){let e=this._$AA.parentNode;const t=this._$AM;return t!==void 0&&(e==null?void 0:e.nodeType)===11&&(e=t.parentNode),e}get startNode(){return this._$AA}get endNode(){return this._$AB}_$AI(e,t=this){e=le(this,e,t),Oe(e)?e===N||e==null||e===""?(this._$AH!==N&&this._$AR(),this._$AH=N):e!==this._$AH&&e!==x&&this._(e):e._$litType$!==void 0?this.g(e):e.nodeType!==void 0?this.$(e):ci(e)?this.T(e):this._(e)}k(e){return this._$AA.parentNode.insertBefore(e,this._$AB)}$(e){this._$AH!==e&&(this._$AR(),this._$AH=this.k(e))}_(e){this._$AH!==N&&Oe(this._$AH)?this._$AA.nextSibling.data=e:this.$(te.createTextNode(e)),this._$AH=e}g(e){var t;const{values:i,_$litType$:o}=e,s=typeof o=="number"?this._$AC(e):(o.el===void 0&&(o.el=Ae.createElement(ln(o.h,o.h[0]),this.options)),o);if(((t=this._$AH)===null||t===void 0?void 0:t._$AD)===s)this._$AH.v(i);else{const a=new ui(s,this),r=a.u(this.options);a.v(i),this.$(r),this._$AH=a}}_$AC(e){let t=$t.get(e.strings);return t===void 0&&$t.set(e.strings,t=new Ae(e)),t}T(e){an(this._$AH)||(this._$AH=[],this._$AR());const t=this._$AH;let i,o=0;for(const s of e)o===t.length?t.push(i=new he(this.k(ge()),this.k(ge()),this,this.options)):i=t[o],i._$AI(s),o++;o<t.length&&(this._$AR(i&&i._$AB.nextSibling,o),t.length=o)}_$AR(e=this._$AA.nextSibling,t){var i;for((i=this._$AP)===null||i===void 0||i.call(this,!1,!0,t);e&&e!==this._$AB;){const o=e.nextSibling;e.remove(),e=o}}setConnected(e){var t;this._$AM===void 0&&(this._$Cp=e,(t=this._$AP)===null||t===void 0||t.call(this,e))}}let xe=class{constructor(e,t,i,o,s){this.type=1,this._$AH=N,this._$AN=void 0,this.element=e,this.name=t,this._$AM=o,this.options=s,i.length>2||i[0]!==""||i[1]!==""?(this._$AH=Array(i.length-1).fill(new String),this.strings=i):this._$AH=N}get tagName(){return this.element.tagName}get _$AU(){return this._$AM._$AU}_$AI(e,t=this,i,o){const s=this.strings;let a=!1;if(s===void 0)e=le(this,e,t,0),a=!Oe(e)||e!==this._$AH&&e!==x,a&&(this._$AH=e);else{const r=e;let l,c;for(e=s[0],l=0;l<s.length-1;l++)c=le(this,r[i+l],t,l),c===x&&(c=this._$AH[l]),a||(a=!Oe(c)||c!==this._$AH[l]),c===N?e=N:e!==N&&(e+=(c??"")+s[l+1]),this._$AH[l]=c}a&&!o&&this.j(e)}j(e){e===N?this.element.removeAttribute(this.name):this.element.setAttribute(this.name,e??"")}};class pi extends xe{constructor(){super(...arguments),this.type=3}j(e){this.element[this.name]=e===N?void 0:e}}const _i=re?re.emptyScript:"";class vi extends xe{constructor(){super(...arguments),this.type=4}j(e){e&&e!==N?this.element.setAttribute(this.name,_i):this.element.removeAttribute(this.name)}}class fi extends xe{constructor(e,t,i,o,s){super(e,t,i,o,s),this.type=5}_$AI(e,t=this){var i;if((e=(i=le(this,e,t,0))!==null&&i!==void 0?i:N)===x)return;const o=this._$AH,s=e===N&&o!==N||e.capture!==o.capture||e.once!==o.once||e.passive!==o.passive,a=e!==N&&(o===N||s);s&&this.element.removeEventListener(this.name,this,o),a&&this.element.addEventListener(this.name,this,e),this._$AH=e}handleEvent(e){var t,i;typeof this._$AH=="function"?this._$AH.call((i=(t=this.options)===null||t===void 0?void 0:t.host)!==null&&i!==void 0?i:this.element,e):this._$AH.handleEvent(e)}}class gi{constructor(e,t,i){this.element=e,this.type=6,this._$AN=void 0,this._$AM=t,this.options=i}get _$AU(){return this._$AM._$AU}_$AI(e){le(this,e)}}const Oi={I:he},xt=be.litHtmlPolyfillSupport;xt==null||xt(Ae,he),((Fe=be.litHtmlVersions)!==null&&Fe!==void 0?Fe:be.litHtmlVersions=[]).push("2.8.0");const Ai=(n,e,t)=>{var i,o;const s=(i=t==null?void 0:t.renderBefore)!==null&&i!==void 0?i:e;let a=s._$litPart$;if(a===void 0){const r=(o=t==null?void 0:t.renderBefore)!==null&&o!==void 0?o:null;s._$litPart$=a=new he(e.insertBefore(ge(),r),r,void 0,t??{})}return a._$AI(n),a};/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var We,Xe;let F=class extends ae{constructor(){super(...arguments),this.renderOptions={host:this},this._$Do=void 0}createRenderRoot(){var e,t;const i=super.createRenderRoot();return(e=(t=this.renderOptions).renderBefore)!==null&&e!==void 0||(t.renderBefore=i.firstChild),i}update(e){const t=this.render();this.hasUpdated||(this.renderOptions.isConnected=this.isConnected),super.update(e),this._$Do=Ai(t,this.renderRoot,this.renderOptions)}connectedCallback(){var e;super.connectedCallback(),(e=this._$Do)===null||e===void 0||e.setConnected(!0)}disconnectedCallback(){var e;super.disconnectedCallback(),(e=this._$Do)===null||e===void 0||e.setConnected(!1)}render(){return x}};F.finalized=!0,F._$litElement$=!0,(We=globalThis.litElementHydrateSupport)===null||We===void 0||We.call(globalThis,{LitElement:F});const kt=globalThis.litElementPolyfillSupport;kt==null||kt({LitElement:F});((Xe=globalThis.litElementVersions)!==null&&Xe!==void 0?Xe:globalThis.litElementVersions=[]).push("3.3.3");/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const ke=n=>e=>typeof e=="function"?((t,i)=>(customElements.define(t,i),i))(n,e):((t,i)=>{const{kind:o,elements:s}=i;return{kind:o,elements:s,finisher(a){customElements.define(t,a)}}})(n,e);/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const mi=(n,e)=>e.kind==="method"&&e.descriptor&&!("value"in e.descriptor)?{...e,finisher(t){t.createProperty(e.key,n)}}:{kind:"field",key:Symbol(),placement:"own",descriptor:{},originalKey:e.key,initializer(){typeof e.initializer=="function"&&(this[e.key]=e.initializer.call(this))},finisher(t){t.createProperty(e.key,n)}},Ni=(n,e,t)=>{e.constructor.createProperty(t,n)};function E(n){return(e,t)=>t!==void 0?Ni(n,e,t):mi(n,e)}/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */function Y(n){return E({...n,state:!0})}/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Je;((Je=window.HTMLSlotElement)===null||Je===void 0?void 0:Je.prototype.assignedElements)!=null;/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const L={ATTRIBUTE:1,CHILD:2,PROPERTY:3,BOOLEAN_ATTRIBUTE:4},Ne=n=>(...e)=>({_$litDirective$:n,values:e});class Ce{constructor(e){}get _$AU(){return this._$AM._$AU}_$AT(e,t,i){this._$Ct=e,this._$AM=t,this._$Ci=i}_$AS(e,t){return this.update(e,t)}update(e,t){return this.render(...t)}}/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const{I:Ci}=Oi,cn=n=>n.strings===void 0,jt=()=>document.createComment(""),pe=(n,e,t)=>{var i;const o=n._$AA.parentNode,s=e===void 0?n._$AB:e._$AA;if(t===void 0){const a=o.insertBefore(jt(),s),r=o.insertBefore(jt(),s);t=new Ci(a,r,n,n.options)}else{const a=t._$AB.nextSibling,r=t._$AM,l=r!==n;if(l){let c;(i=t._$AQ)===null||i===void 0||i.call(t,n),t._$AM=n,t._$AP!==void 0&&(c=n._$AU)!==r._$AU&&t._$AP(c)}if(a!==s||l){let c=t._$AA;for(;c!==a;){const h=c.nextSibling;o.insertBefore(c,s),c=h}}}return t},J=(n,e,t=n)=>(n._$AI(e,t),n),Mi={},hn=(n,e=Mi)=>n._$AH=e,Si=n=>n._$AH,qe=n=>{var e;(e=n._$AP)===null||e===void 0||e.call(n,!1,!0);let t=n._$AA;const i=n._$AB.nextSibling;for(;t!==i;){const o=t.nextSibling;t.remove(),t=o}};/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Dt=(n,e,t)=>{const i=new Map;for(let o=e;o<=t;o++)i.set(n[o],o);return i},wi=Ne(class extends Ce{constructor(n){if(super(n),n.type!==L.CHILD)throw Error("repeat() can only be used in text expressions")}ct(n,e,t){let i;t===void 0?t=e:e!==void 0&&(i=e);const o=[],s=[];let a=0;for(const r of n)o[a]=i?i(r,a):a,s[a]=t(r,a),a++;return{values:s,keys:o}}render(n,e,t){return this.ct(n,e,t).values}update(n,[e,t,i]){var o;const s=Si(n),{values:a,keys:r}=this.ct(e,t,i);if(!Array.isArray(s))return this.ut=r,a;const l=(o=this.ut)!==null&&o!==void 0?o:this.ut=[],c=[];let h,d,u=0,p=s.length-1,v=0,A=a.length-1;for(;u<=p&&v<=A;)if(s[u]===null)u++;else if(s[p]===null)p--;else if(l[u]===r[v])c[v]=J(s[u],a[v]),u++,v++;else if(l[p]===r[A])c[A]=J(s[p],a[A]),p--,A--;else if(l[u]===r[A])c[A]=J(s[u],a[A]),pe(n,c[A+1],s[u]),u++,A--;else if(l[p]===r[v])c[v]=J(s[p],a[v]),pe(n,s[u],s[p]),p--,v++;else if(h===void 0&&(h=Dt(r,v,A),d=Dt(l,u,p)),h.has(l[u]))if(h.has(l[p])){const $=d.get(r[v]),W=$!==void 0?s[$]:null;if(W===null){const V=pe(n,s[u]);J(V,a[v]),c[v]=V}else c[v]=J(W,a[v]),pe(n,s[u],W),s[$]=null;v++}else qe(s[p]),p--;else qe(s[u]),u++;for(;v<=A;){const $=pe(n,c[A+1]);J($,a[v]),c[v++]=$}for(;u<=p;){const $=s[u++];$!==null&&qe($)}return this.ut=r,hn(n,c),x}});/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Ei=Ne(class extends Ce{constructor(n){if(super(n),n.type!==L.PROPERTY&&n.type!==L.ATTRIBUTE&&n.type!==L.BOOLEAN_ATTRIBUTE)throw Error("The `live` directive is not allowed on child or event bindings");if(!cn(n))throw Error("`live` bindings can only contain a single expression")}render(n){return n}update(n,[e]){if(e===x||e===N)return e;const t=n.element,i=n.name;if(n.type===L.PROPERTY){if(e===t[i])return x}else if(n.type===L.BOOLEAN_ATTRIBUTE){if(!!e===t.hasAttribute(i))return x}else if(n.type===L.ATTRIBUTE&&t.getAttribute(i)===e+"")return x;return hn(n),e}});/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const ve=(n,e)=>{var t,i;const o=n._$AN;if(o===void 0)return!1;for(const s of o)(i=(t=s)._$AO)===null||i===void 0||i.call(t,e,!1),ve(s,e);return!0},Re=n=>{let e,t;do{if((e=n._$AM)===void 0)break;t=e._$AN,t.delete(n),n=e}while((t==null?void 0:t.size)===0)},dn=n=>{for(let e;e=n._$AM;n=e){let t=e._$AN;if(t===void 0)e._$AN=t=new Set;else if(t.has(n))break;t.add(n),Ii(e)}};function yi(n){this._$AN!==void 0?(Re(this),this._$AM=n,dn(this)):this._$AM=n}function Ti(n,e=!1,t=0){const i=this._$AH,o=this._$AN;if(o!==void 0&&o.size!==0)if(e)if(Array.isArray(i))for(let s=t;s<i.length;s++)ve(i[s],!1),Re(i[s]);else i!=null&&(ve(i,!1),Re(i));else ve(this,n)}const Ii=n=>{var e,t,i,o;n.type==L.CHILD&&((e=(i=n)._$AP)!==null&&e!==void 0||(i._$AP=Ti),(t=(o=n)._$AQ)!==null&&t!==void 0||(o._$AQ=yi))};class bi extends Ce{constructor(){super(...arguments),this._$AN=void 0}_$AT(e,t,i){super._$AT(e,t,i),dn(this),this.isConnected=e._$AU}_$AO(e,t=!0){var i,o;e!==this.isConnected&&(this.isConnected=e,e?(i=this.reconnected)===null||i===void 0||i.call(this):(o=this.disconnected)===null||o===void 0||o.call(this)),t&&(ve(this,e),Re(this))}setValue(e){if(cn(this._$Ct))this._$Ct._$AI(e,this);else{const t=[...this._$Ct._$AH];t[this._$Ci]=e,this._$Ct._$AI(t,this,0)}}disconnected(){}reconnected(){}}/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const un=()=>new Ri;let Ri=class{};const Qe=new WeakMap,pn=Ne(class extends bi{render(n){return N}update(n,[e]){var t;const i=e!==this.G;return i&&this.G!==void 0&&this.ot(void 0),(i||this.rt!==this.lt)&&(this.G=e,this.dt=(t=n.options)===null||t===void 0?void 0:t.host,this.ot(this.lt=n.element)),N}ot(n){var e;if(typeof this.G=="function"){const t=(e=this.dt)!==null&&e!==void 0?e:globalThis;let i=Qe.get(t);i===void 0&&(i=new WeakMap,Qe.set(t,i)),i.get(this.G)!==void 0&&this.G.call(this.dt,void 0),i.set(this.G,n),n!==void 0&&this.G.call(this.dt,n)}else this.G.value=n}get rt(){var n,e,t;return typeof this.G=="function"?(e=Qe.get((n=this.dt)!==null&&n!==void 0?n:globalThis))===null||e===void 0?void 0:e.get(this.G):(t=this.G)===null||t===void 0?void 0:t.value}disconnected(){this.rt===this.lt&&this.ot(void 0)}reconnected(){this.ot(this.lt)}});/**
 * @license
 * Copyright 2018 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const dt=Ne(class extends Ce{constructor(n){var e;if(super(n),n.type!==L.ATTRIBUTE||n.name!=="class"||((e=n.strings)===null||e===void 0?void 0:e.length)>2)throw Error("`classMap()` can only be used in the `class` attribute and must be the only part in the attribute.")}render(n){return" "+Object.keys(n).filter((e=>n[e])).join(" ")+" "}update(n,[e]){var t,i;if(this.it===void 0){this.it=new Set,n.strings!==void 0&&(this.nt=new Set(n.strings.join(" ").split(/\s/).filter((s=>s!==""))));for(const s in e)e[s]&&!(!((t=this.nt)===null||t===void 0)&&t.has(s))&&this.it.add(s);return this.render(e)}const o=n.element.classList;this.it.forEach((s=>{s in e||(o.remove(s),this.it.delete(s))}));for(const s in e){const a=!!e[s];a===this.it.has(s)||!((i=this.nt)===null||i===void 0)&&i.has(s)||(a?(o.add(s),this.it.add(s)):(o.remove(s),this.it.delete(s)))}return x}});/*!
 * hotkeys-js v3.8.7
 * A simple micro-library for defining and dispatching keyboard shortcuts. It has no dependencies.
 * 
 * Copyright (c) 2021 kenny wong <wowohoo@qq.com>
 * http://jaywcjlove.github.io/hotkeys
 * 
 * Licensed under the MIT license.
 */var et=typeof navigator<"u"?navigator.userAgent.toLowerCase().indexOf("firefox")>0:!1;function tt(n,e,t){n.addEventListener?n.addEventListener(e,t,!1):n.attachEvent&&n.attachEvent("on".concat(e),function(){t(window.event)})}function _n(n,e){for(var t=e.slice(0,e.length-1),i=0;i<t.length;i++)t[i]=n[t[i].toLowerCase()];return t}function vn(n){typeof n!="string"&&(n=""),n=n.replace(/\s/g,"");for(var e=n.split(","),t=e.lastIndexOf("");t>=0;)e[t-1]+=",",e.splice(t,1),t=e.lastIndexOf("");return e}function $i(n,e){for(var t=n.length>=e.length?n:e,i=n.length>=e.length?e:n,o=!0,s=0;s<t.length;s++)i.indexOf(t[s])===-1&&(o=!1);return o}var fn={backspace:8,tab:9,clear:12,enter:13,return:13,esc:27,escape:27,space:32,left:37,up:38,right:39,down:40,del:46,delete:46,ins:45,insert:45,home:36,end:35,pageup:33,pagedown:34,capslock:20,num_0:96,num_1:97,num_2:98,num_3:99,num_4:100,num_5:101,num_6:102,num_7:103,num_8:104,num_9:105,num_multiply:106,num_add:107,num_enter:108,num_subtract:109,num_decimal:110,num_divide:111,"⇪":20,",":188,".":190,"/":191,"`":192,"-":et?173:189,"=":et?61:187,";":et?59:186,"'":222,"[":219,"]":221,"\\":220},ne={"⇧":16,shift:16,"⌥":18,alt:18,option:18,"⌃":17,ctrl:17,control:17,"⌘":91,cmd:91,command:91},Bt={16:"shiftKey",18:"altKey",17:"ctrlKey",91:"metaKey",shiftKey:16,ctrlKey:17,altKey:18,metaKey:91},T={16:!1,18:!1,17:!1,91:!1},y={};for(var ye=1;ye<20;ye++)fn["f".concat(ye)]=111+ye;var m=[],gn="all",On=[],je=function(e){return fn[e.toLowerCase()]||ne[e.toLowerCase()]||e.toUpperCase().charCodeAt(0)};function An(n){gn=n||"all"}function me(){return gn||"all"}function xi(){return m.slice(0)}function ki(n){var e=n.target||n.srcElement,t=e.tagName,i=!0;return(e.isContentEditable||(t==="INPUT"||t==="TEXTAREA"||t==="SELECT")&&!e.readOnly)&&(i=!1),i}function ji(n){return typeof n=="string"&&(n=je(n)),m.indexOf(n)!==-1}function Di(n,e){var t,i;n||(n=me());for(var o in y)if(Object.prototype.hasOwnProperty.call(y,o))for(t=y[o],i=0;i<t.length;)t[i].scope===n?t.splice(i,1):i++;me()===n&&An(e||"all")}function Bi(n){var e=n.keyCode||n.which||n.charCode,t=m.indexOf(e);if(t>=0&&m.splice(t,1),n.key&&n.key.toLowerCase()==="meta"&&m.splice(0,m.length),(e===93||e===224)&&(e=91),e in T){T[e]=!1;for(var i in ne)ne[i]===e&&(M[i]=!1)}}function Li(n){if(!n)Object.keys(y).forEach(function(a){return delete y[a]});else if(Array.isArray(n))n.forEach(function(a){a.key&&nt(a)});else if(typeof n=="object")n.key&&nt(n);else if(typeof n=="string"){for(var e=arguments.length,t=new Array(e>1?e-1:0),i=1;i<e;i++)t[i-1]=arguments[i];var o=t[0],s=t[1];typeof o=="function"&&(s=o,o=""),nt({key:n,scope:o,method:s,splitKey:"+"})}}var nt=function(e){var t=e.key,i=e.scope,o=e.method,s=e.splitKey,a=s===void 0?"+":s,r=vn(t);r.forEach(function(l){var c=l.split(a),h=c.length,d=c[h-1],u=d==="*"?"*":je(d);if(y[u]){i||(i=me());var p=h>1?_n(ne,c):[];y[u]=y[u].map(function(v){var A=o?v.method===o:!0;return A&&v.scope===i&&$i(v.mods,p)?{}:v})}})};function Lt(n,e,t){var i;if(e.scope===t||e.scope==="all"){i=e.mods.length>0;for(var o in T)Object.prototype.hasOwnProperty.call(T,o)&&(!T[o]&&e.mods.indexOf(+o)>-1||T[o]&&e.mods.indexOf(+o)===-1)&&(i=!1);(e.mods.length===0&&!T[16]&&!T[18]&&!T[17]&&!T[91]||i||e.shortcut==="*")&&e.method(n,e)===!1&&(n.preventDefault?n.preventDefault():n.returnValue=!1,n.stopPropagation&&n.stopPropagation(),n.cancelBubble&&(n.cancelBubble=!0))}}function Ht(n){var e=y["*"],t=n.keyCode||n.which||n.charCode;if(M.filter.call(this,n)){if((t===93||t===224)&&(t=91),m.indexOf(t)===-1&&t!==229&&m.push(t),["ctrlKey","altKey","shiftKey","metaKey"].forEach(function(p){var v=Bt[p];n[p]&&m.indexOf(v)===-1?m.push(v):!n[p]&&m.indexOf(v)>-1?m.splice(m.indexOf(v),1):p==="metaKey"&&n[p]&&m.length===3&&(n.ctrlKey||n.shiftKey||n.altKey||(m=m.slice(m.indexOf(v))))}),t in T){T[t]=!0;for(var i in ne)ne[i]===t&&(M[i]=!0);if(!e)return}for(var o in T)Object.prototype.hasOwnProperty.call(T,o)&&(T[o]=n[Bt[o]]);n.getModifierState&&!(n.altKey&&!n.ctrlKey)&&n.getModifierState("AltGraph")&&(m.indexOf(17)===-1&&m.push(17),m.indexOf(18)===-1&&m.push(18),T[17]=!0,T[18]=!0);var s=me();if(e)for(var a=0;a<e.length;a++)e[a].scope===s&&(n.type==="keydown"&&e[a].keydown||n.type==="keyup"&&e[a].keyup)&&Lt(n,e[a],s);if(t in y){for(var r=0;r<y[t].length;r++)if((n.type==="keydown"&&y[t][r].keydown||n.type==="keyup"&&y[t][r].keyup)&&y[t][r].key){for(var l=y[t][r],c=l.splitKey,h=l.key.split(c),d=[],u=0;u<h.length;u++)d.push(je(h[u]));d.sort().join("")===m.sort().join("")&&Lt(n,l,s)}}}}function Hi(n){return On.indexOf(n)>-1}function M(n,e,t){m=[];var i=vn(n),o=[],s="all",a=document,r=0,l=!1,c=!0,h="+";for(t===void 0&&typeof e=="function"&&(t=e),Object.prototype.toString.call(e)==="[object Object]"&&(e.scope&&(s=e.scope),e.element&&(a=e.element),e.keyup&&(l=e.keyup),e.keydown!==void 0&&(c=e.keydown),typeof e.splitKey=="string"&&(h=e.splitKey)),typeof e=="string"&&(s=e);r<i.length;r++)n=i[r].split(h),o=[],n.length>1&&(o=_n(ne,n)),n=n[n.length-1],n=n==="*"?"*":je(n),n in y||(y[n]=[]),y[n].push({keyup:l,keydown:c,scope:s,mods:o,shortcut:i[r],method:t,key:i[r],splitKey:h});typeof a<"u"&&!Hi(a)&&window&&(On.push(a),tt(a,"keydown",function(d){Ht(d)}),tt(window,"focus",function(){m=[]}),tt(a,"keyup",function(d){Ht(d),Bi(d)}))}var it={setScope:An,getScope:me,deleteScope:Di,getPressedKeyCodes:xi,isPressed:ji,filter:ki,unbind:Li};for(var ot in it)Object.prototype.hasOwnProperty.call(it,ot)&&(M[ot]=it[ot]);if(typeof window<"u"){var Pi=window.hotkeys;M.noConflict=function(n){return n&&window.hotkeys===M&&(window.hotkeys=Pi),M},window.hotkeys=M}var Me=function(n,e,t,i){var o=arguments.length,s=o<3?e:i===null?i=Object.getOwnPropertyDescriptor(e,t):i,a;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(n,e,t,i);else for(var r=n.length-1;r>=0;r--)(a=n[r])&&(s=(o<3?a(s):o>3?a(e,t,s):a(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let ie=class extends F{constructor(){super(...arguments),this.placeholder="",this.hideBreadcrumbs=!1,this.breadcrumbHome="Home",this.breadcrumbs=[],this._inputRef=un()}render(){let e="";if(!this.hideBreadcrumbs){const t=[];for(const i of this.breadcrumbs)t.push(I`<button
            tabindex="-1"
            @click=${()=>this.selectParent(i)}
            class="breadcrumb"
          >
            ${i}
          </button>`);e=I`<div class="breadcrumb-list">
        <button
          tabindex="-1"
          @click=${()=>this.selectParent()}
          class="breadcrumb"
        >
          ${this.breadcrumbHome}
        </button>
        ${t}
      </div>`}return I`
      ${e}
      <div part="ninja-input-wrapper" class="search-wrapper">
        <input
          part="ninja-input"
          type="text"
          id="search"
          spellcheck="false"
          autocomplete="off"
          @input="${this._handleInput}"
          ${pn(this._inputRef)}
          placeholder="${this.placeholder}"
          class="search"
        />
      </div>
    `}setSearch(e){this._inputRef.value&&(this._inputRef.value.value=e)}focusSearch(){requestAnimationFrame(()=>this._inputRef.value.focus())}_handleInput(e){const t=e.target;this.dispatchEvent(new CustomEvent("change",{detail:{search:t.value},bubbles:!1,composed:!1}))}selectParent(e){this.dispatchEvent(new CustomEvent("setParent",{detail:{parent:e},bubbles:!0,composed:!0}))}firstUpdated(){this.focusSearch()}_close(){this.dispatchEvent(new CustomEvent("close",{bubbles:!0,composed:!0}))}};ie.styles=$e`
    :host {
      flex: 1;
      position: relative;
    }
    .search {
      padding: 1.25em;
      flex-grow: 1;
      flex-shrink: 0;
      margin: 0px;
      border: none;
      appearance: none;
      font-size: 1.125em;
      background: transparent;
      caret-color: var(--ninja-accent-color);
      color: var(--ninja-text-color);
      outline: none;
      font-family: var(--ninja-font-family);
    }
    .search::placeholder {
      color: var(--ninja-placeholder-color);
    }
    .breadcrumb-list {
      padding: 1em 4em 0 1em;
      display: flex;
      flex-direction: row;
      align-items: stretch;
      justify-content: flex-start;
      flex: initial;
    }

    .breadcrumb {
      background: var(--ninja-secondary-background-color);
      text-align: center;
      line-height: 1.2em;
      border-radius: var(--ninja-key-border-radius);
      border: 0;
      cursor: pointer;
      padding: 0.1em 0.5em;
      color: var(--ninja-secondary-text-color);
      margin-right: 0.5em;
      outline: none;
      font-family: var(--ninja-font-family);
    }

    .search-wrapper {
      display: flex;
      border-bottom: var(--ninja-separate-border);
    }
  `;Me([E()],ie.prototype,"placeholder",void 0);Me([E({type:Boolean})],ie.prototype,"hideBreadcrumbs",void 0);Me([E()],ie.prototype,"breadcrumbHome",void 0);Me([E({type:Array})],ie.prototype,"breadcrumbs",void 0);ie=Me([ke("ninja-header")],ie);/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */class ut extends Ce{constructor(e){if(super(e),this.et=N,e.type!==L.CHILD)throw Error(this.constructor.directiveName+"() can only be used in child bindings")}render(e){if(e===N||e==null)return this.ft=void 0,this.et=e;if(e===x)return e;if(typeof e!="string")throw Error(this.constructor.directiveName+"() called with a non-string value");if(e===this.et)return this.ft;this.et=e;const t=[e];return t.raw=t,this.ft={_$litType$:this.constructor.resultType,strings:t,values:[]}}}ut.directiveName="unsafeHTML",ut.resultType=1;const Zi=Ne(ut);/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */function*Vi(n,e){if(n!==void 0){let t=-1;for(const i of n)t>-1&&(yield e),t++,yield i}}/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-LIcense-Identifier: Apache-2.0
 */const Ui=$e`:host{font-family:var(--mdc-icon-font, "Material Icons");font-weight:normal;font-style:normal;font-size:var(--mdc-icon-size, 24px);line-height:1;letter-spacing:normal;text-transform:none;display:inline-block;white-space:nowrap;word-wrap:normal;direction:ltr;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;-moz-osx-font-smoothing:grayscale;font-feature-settings:"liga"}`;/**
 * @license
 * Copyright 2018 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */let pt=class extends F{render(){return I`<span><slot></slot></span>`}};pt.styles=[Ui];pt=kn([ke("mwc-icon")],pt);var De=function(n,e,t,i){var o=arguments.length,s=o<3?e:i===null?i=Object.getOwnPropertyDescriptor(e,t):i,a;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(n,e,t,i);else for(var r=n.length-1;r>=0;r--)(a=n[r])&&(s=(o<3?a(s):o>3?a(e,t,s):a(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let ce=class extends F{constructor(){super(),this.selected=!1,this.hotKeysJoinedView=!0,this.addEventListener("click",this.click)}ensureInView(){requestAnimationFrame(()=>this.scrollIntoView({block:"nearest"}))}click(){this.dispatchEvent(new CustomEvent("actionsSelected",{detail:this.action,bubbles:!0,composed:!0}))}updated(e){e.has("selected")&&this.selected&&this.ensureInView()}render(){let e;this.action.mdIcon?e=I`<mwc-icon part="ninja-icon" class="ninja-icon"
        >${this.action.mdIcon}</mwc-icon
      >`:this.action.icon&&(e=Zi(this.action.icon||""));let t;this.action.hotkey&&(this.hotKeysJoinedView?t=this.action.hotkey.split(",").map(o=>{const s=o.split("+"),a=I`${Vi(s.map(r=>I`<kbd>${r}</kbd>`),"+")}`;return I`<div class="ninja-hotkey ninja-hotkeys">
            ${a}
          </div>`}):t=this.action.hotkey.split(",").map(o=>{const a=o.split("+").map(r=>I`<kbd class="ninja-hotkey">${r}</kbd>`);return I`<kbd class="ninja-hotkeys">${a}</kbd>`}));const i={selected:this.selected,"ninja-action":!0};return I`
      <div
        class="ninja-action"
        part="ninja-action ${this.selected?"ninja-selected":""}"
        class=${dt(i)}
      >
        ${e}
        <div class="ninja-title">${this.action.title}</div>
        ${t}
      </div>
    `}};ce.styles=$e`
    :host {
      display: flex;
      width: 100%;
    }
    .ninja-action {
      padding: 0.75em 1em;
      display: flex;
      border-left: 2px solid transparent;
      align-items: center;
      justify-content: start;
      outline: none;
      transition: color 0s ease 0s;
      width: 100%;
    }
    .ninja-action.selected {
      cursor: pointer;
      color: var(--ninja-selected-text-color);
      background-color: var(--ninja-selected-background);
      border-left: 2px solid var(--ninja-accent-color);
      outline: none;
    }
    .ninja-action.selected .ninja-icon {
      color: var(--ninja-selected-text-color);
    }
    .ninja-icon {
      font-size: var(--ninja-icon-size);
      max-width: var(--ninja-icon-size);
      max-height: var(--ninja-icon-size);
      margin-right: 1em;
      color: var(--ninja-icon-color);
      margin-right: 1em;
      position: relative;
    }

    .ninja-title {
      flex-shrink: 0.01;
      margin-right: 0.5em;
      flex-grow: 1;
      font-size: 0.8125em;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .ninja-hotkeys {
      flex-shrink: 0;
      width: min-content;
      display: flex;
    }

    .ninja-hotkeys kbd {
      font-family: inherit;
    }
    .ninja-hotkey {
      background: var(--ninja-secondary-background-color);
      padding: 0.06em 0.25em;
      border-radius: var(--ninja-key-border-radius);
      text-transform: capitalize;
      color: var(--ninja-secondary-text-color);
      font-size: 0.75em;
      font-family: inherit;
    }

    .ninja-hotkey + .ninja-hotkey {
      margin-left: 0.5em;
    }
    .ninja-hotkeys + .ninja-hotkeys {
      margin-left: 1em;
    }
  `;De([E({type:Object})],ce.prototype,"action",void 0);De([E({type:Boolean})],ce.prototype,"selected",void 0);De([E({type:Boolean})],ce.prototype,"hotKeysJoinedView",void 0);ce=De([ke("ninja-action")],ce);const Gi=I` <div class="modal-footer" slot="footer">
  <span class="help">
    <svg
      version="1.0"
      class="ninja-examplekey"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 1280 1280"
    >
      <path
        d="M1013 376c0 73.4-.4 113.3-1.1 120.2a159.9 159.9 0 0 1-90.2 127.3c-20 9.6-36.7 14-59.2 15.5-7.1.5-121.9.9-255 1h-242l95.5-95.5 95.5-95.5-38.3-38.2-38.2-38.3-160 160c-88 88-160 160.4-160 161 0 .6 72 73 160 161l160 160 38.2-38.3 38.3-38.2-95.5-95.5-95.5-95.5h251.1c252.9 0 259.8-.1 281.4-3.6 72.1-11.8 136.9-54.1 178.5-116.4 8.6-12.9 22.6-40.5 28-55.4 4.4-12 10.7-36.1 13.1-50.6 1.6-9.6 1.8-21 2.1-132.8l.4-122.2H1013v110z"
      />
    </svg>

    to select
  </span>
  <span class="help">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="ninja-examplekey"
      viewBox="0 0 24 24"
    >
      <path d="M0 0h24v24H0V0z" fill="none" />
      <path
        d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"
      />
    </svg>
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="ninja-examplekey"
      viewBox="0 0 24 24"
    >
      <path d="M0 0h24v24H0V0z" fill="none" />
      <path d="M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z" />
    </svg>
    to navigate
  </span>
  <span class="help">
    <span class="ninja-examplekey esc">esc</span>
    to close
  </span>
  <span class="help">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="ninja-examplekey backspace"
      viewBox="0 0 20 20"
      fill="currentColor"
    >
      <path
        fill-rule="evenodd"
        d="M6.707 4.879A3 3 0 018.828 4H15a3 3 0 013 3v6a3 3 0 01-3 3H8.828a3 3 0 01-2.12-.879l-4.415-4.414a1 1 0 010-1.414l4.414-4.414zm4 2.414a1 1 0 00-1.414 1.414L10.586 10l-1.293 1.293a1 1 0 101.414 1.414L12 11.414l1.293 1.293a1 1 0 001.414-1.414L13.414 10l1.293-1.293a1 1 0 00-1.414-1.414L12 8.586l-1.293-1.293z"
        clip-rule="evenodd"
      />
    </svg>
    move to parent
  </span>
</div>`,Ki=$e`
  :host {
    --ninja-width: 640px;
    --ninja-backdrop-filter: none;
    --ninja-overflow-background: rgba(255, 255, 255, 0.5);
    --ninja-text-color: rgb(60, 65, 73);
    --ninja-font-size: 16px;
    --ninja-top: 20%;

    --ninja-key-border-radius: 0.25em;
    --ninja-accent-color: rgb(110, 94, 210);
    --ninja-secondary-background-color: rgb(239, 241, 244);
    --ninja-secondary-text-color: rgb(107, 111, 118);

    --ninja-selected-background: rgb(248, 249, 251);

    --ninja-icon-color: var(--ninja-secondary-text-color);
    --ninja-icon-size: 1.2em;
    --ninja-separate-border: 1px solid var(--ninja-secondary-background-color);

    --ninja-modal-background: #fff;
    --ninja-modal-shadow: rgb(0 0 0 / 50%) 0px 16px 70px;

    --ninja-actions-height: 300px;
    --ninja-group-text-color: rgb(144, 149, 157);

    --ninja-footer-background: rgba(242, 242, 242, 0.4);

    --ninja-placeholder-color: #8e8e8e;

    font-size: var(--ninja-font-size);

    --ninja-z-index: 1;
  }

  :host(.dark) {
    --ninja-backdrop-filter: none;
    --ninja-overflow-background: rgba(0, 0, 0, 0.7);
    --ninja-text-color: #7d7d7d;

    --ninja-modal-background: rgba(17, 17, 17, 0.85);
    --ninja-accent-color: rgb(110, 94, 210);
    --ninja-secondary-background-color: rgba(51, 51, 51, 0.44);
    --ninja-secondary-text-color: #888;

    --ninja-selected-text-color: #eaeaea;
    --ninja-selected-background: rgba(51, 51, 51, 0.44);

    --ninja-icon-color: var(--ninja-secondary-text-color);
    --ninja-separate-border: 1px solid var(--ninja-secondary-background-color);

    --ninja-modal-shadow: 0 16px 70px rgba(0, 0, 0, 0.2);

    --ninja-group-text-color: rgb(144, 149, 157);

    --ninja-footer-background: rgba(30, 30, 30, 85%);
  }

  .modal {
    display: none;
    position: fixed;
    z-index: var(--ninja-z-index);
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background: var(--ninja-overflow-background);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    -webkit-backdrop-filter: var(--ninja-backdrop-filter);
    backdrop-filter: var(--ninja-backdrop-filter);
    text-align: left;
    color: var(--ninja-text-color);
    font-family: var(--ninja-font-family);
  }
  .modal.visible {
    display: block;
  }

  .modal-content {
    position: relative;
    top: var(--ninja-top);
    margin: auto;
    padding: 0;
    display: flex;
    flex-direction: column;
    flex-shrink: 1;
    -webkit-box-flex: 1;
    flex-grow: 1;
    min-width: 0px;
    will-change: transform;
    background: var(--ninja-modal-background);
    border-radius: 0.5em;
    box-shadow: var(--ninja-modal-shadow);
    max-width: var(--ninja-width);
    overflow: hidden;
  }

  .bump {
    animation: zoom-in-zoom-out 0.2s ease;
  }

  @keyframes zoom-in-zoom-out {
    0% {
      transform: scale(0.99);
    }
    50% {
      transform: scale(1.01, 1.01);
    }
    100% {
      transform: scale(1, 1);
    }
  }

  .ninja-github {
    color: var(--ninja-keys-text-color);
    font-weight: normal;
    text-decoration: none;
  }

  .actions-list {
    max-height: var(--ninja-actions-height);
    overflow: auto;
    scroll-behavior: smooth;
    position: relative;
    margin: 0;
    padding: 0.5em 0;
    list-style: none;
    scroll-behavior: smooth;
  }

  .group-header {
    height: 1.375em;
    line-height: 1.375em;
    padding-left: 1.25em;
    padding-top: 0.5em;
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
    font-size: 0.75em;
    line-height: 1em;
    color: var(--ninja-group-text-color);
    margin: 1px 0;
  }

  .modal-footer {
    background: var(--ninja-footer-background);
    padding: 0.5em 1em;
    display: flex;
    /* font-size: 0.75em; */
    border-top: var(--ninja-separate-border);
    color: var(--ninja-secondary-text-color);
  }

  .modal-footer .help {
    display: flex;
    margin-right: 1em;
    align-items: center;
    font-size: 0.75em;
  }

  .ninja-examplekey {
    background: var(--ninja-secondary-background-color);
    padding: 0.06em 0.25em;
    border-radius: var(--ninja-key-border-radius);
    color: var(--ninja-secondary-text-color);
    width: 1em;
    height: 1em;
    margin-right: 0.5em;
    font-size: 1.25em;
    fill: currentColor;
  }
  .ninja-examplekey.esc {
    width: auto;
    height: auto;
    font-size: 1.1em;
  }
  .ninja-examplekey.backspace {
    opacity: 0.7;
  }
`;var S=function(n,e,t,i){var o=arguments.length,s=o<3?e:i===null?i=Object.getOwnPropertyDescriptor(e,t):i,a;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(n,e,t,i);else for(var r=n.length-1;r>=0;r--)(a=n[r])&&(s=(o<3?a(s):o>3?a(e,t,s):a(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let C=class extends F{constructor(){super(...arguments),this.placeholder="Type a command or search...",this.disableHotkeys=!1,this.hideBreadcrumbs=!1,this.openHotkey="cmd+k,ctrl+k",this.navigationUpHotkey="up,shift+tab",this.navigationDownHotkey="down,tab",this.closeHotkey="esc",this.goBackHotkey="backspace",this.selectHotkey="enter",this.hotKeysJoinedView=!1,this.noAutoLoadMdIcons=!1,this.data=[],this.visible=!1,this._bump=!0,this._actionMatches=[],this._search="",this._flatData=[],this._headerRef=un()}open(e={}){this._bump=!0,this.visible=!0,this._headerRef.value.focusSearch(),this._actionMatches.length>0&&(this._selected=this._actionMatches[0]),this.setParent(e.parent)}close(){this._bump=!1,this.visible=!1,this.dispatchEvent(new CustomEvent("closed",{bubbles:!0,composed:!0}))}setParent(e){e?this._currentRoot=e:this._currentRoot=void 0,this._selected=void 0,this._search="",this._headerRef.value.setSearch("")}get breadcrumbs(){var e;const t=[];let i=(e=this._selected)===null||e===void 0?void 0:e.parent;if(i)for(t.push(i);i;){const o=this._flatData.find(s=>s.id===i);o!=null&&o.parent&&t.push(o.parent),i=o?o.parent:void 0}return t.reverse()}connectedCallback(){super.connectedCallback(),this.noAutoLoadMdIcons||document.fonts.load("24px Material Icons","apps").then(()=>{}),this._registerInternalHotkeys()}disconnectedCallback(){super.disconnectedCallback(),this._unregisterInternalHotkeys()}_flattern(e,t){let i=[];return e||(e=[]),e.map(o=>{const s=o.children&&o.children.some(r=>typeof r=="string"),a={...o,parent:o.parent||t};return s||(a.children&&a.children.length&&(t=o.id,i=[...i,...a.children]),a.children=a.children?a.children.map(r=>r.id):[]),a}).concat(i.length?this._flattern(i,t):i)}update(e){e.has("data")&&!this.disableHotkeys&&(this._flatData=this._flattern(this.data),this._flatData.filter(t=>!!t.hotkey).forEach(t=>{M(t.hotkey,i=>{i.preventDefault(),t.handler&&t.handler(t)})})),super.update(e)}_registerInternalHotkeys(){this.openHotkey&&M(this.openHotkey,e=>{e.preventDefault(),this.visible?this.close():this.open()}),this.selectHotkey&&M(this.selectHotkey,e=>{this.visible&&(e.preventDefault(),this._actionSelected(this._actionMatches[this._selectedIndex]))}),this.goBackHotkey&&M(this.goBackHotkey,e=>{this.visible&&(this._search||(e.preventDefault(),this._goBack()))}),this.navigationDownHotkey&&M(this.navigationDownHotkey,e=>{this.visible&&(e.preventDefault(),this._selectedIndex>=this._actionMatches.length-1?this._selected=this._actionMatches[0]:this._selected=this._actionMatches[this._selectedIndex+1])}),this.navigationUpHotkey&&M(this.navigationUpHotkey,e=>{this.visible&&(e.preventDefault(),this._selectedIndex===0?this._selected=this._actionMatches[this._actionMatches.length-1]:this._selected=this._actionMatches[this._selectedIndex-1])}),this.closeHotkey&&M(this.closeHotkey,()=>{this.visible&&this.close()})}_unregisterInternalHotkeys(){this.openHotkey&&M.unbind(this.openHotkey),this.selectHotkey&&M.unbind(this.selectHotkey),this.goBackHotkey&&M.unbind(this.goBackHotkey),this.navigationDownHotkey&&M.unbind(this.navigationDownHotkey),this.navigationUpHotkey&&M.unbind(this.navigationUpHotkey),this.closeHotkey&&M.unbind(this.closeHotkey)}_actionFocused(e,t){this._selected=e,t.target.ensureInView()}_onTransitionEnd(){this._bump=!1}_goBack(){const e=this.breadcrumbs.length>1?this.breadcrumbs[this.breadcrumbs.length-2]:void 0;this.setParent(e)}render(){const e={bump:this._bump,"modal-content":!0},t={visible:this.visible,modal:!0},o=this._flatData.filter(r=>{var l;const c=new RegExp(this._search,"gi"),h=r.title.match(c)||((l=r.keywords)===null||l===void 0?void 0:l.match(c));return(!this._currentRoot&&this._search||r.parent===this._currentRoot)&&h}).reduce((r,l)=>r.set(l.section,[...r.get(l.section)||[],l]),new Map);this._actionMatches=[...o.values()].flat(),this._actionMatches.length>0&&this._selectedIndex===-1&&(this._selected=this._actionMatches[0]),this._actionMatches.length===0&&(this._selected=void 0);const s=r=>I` ${wi(r,l=>l.id,l=>{var c;return I`<ninja-action
            exportparts="ninja-action,ninja-selected,ninja-icon"
            .selected=${Ei(l.id===((c=this._selected)===null||c===void 0?void 0:c.id))}
            .hotKeysJoinedView=${this.hotKeysJoinedView}
            @mouseover=${h=>this._actionFocused(l,h)}
            @actionsSelected=${h=>this._actionSelected(h.detail)}
            .action=${l}
          ></ninja-action>`})}`,a=[];return o.forEach((r,l)=>{const c=l?I`<div class="group-header">${l}</div>`:void 0;a.push(I`${c}${s(r)}`)}),I`
      <div @click=${this._overlayClick} class=${dt(t)}>
        <div class=${dt(e)} @animationend=${this._onTransitionEnd}>
          <ninja-header
            exportparts="ninja-input,ninja-input-wrapper"
            ${pn(this._headerRef)}
            .placeholder=${this.placeholder}
            .hideBreadcrumbs=${this.hideBreadcrumbs}
            .breadcrumbs=${this.breadcrumbs}
            @change=${this._handleInput}
            @setParent=${r=>this.setParent(r.detail.parent)}
            @close=${this.close}
          >
          </ninja-header>
          <div class="modal-body">
            <div class="actions-list" part="actions-list">${a}</div>
          </div>
          <slot name="footer"> ${Gi} </slot>
        </div>
      </div>
    `}get _selectedIndex(){return this._selected?this._actionMatches.indexOf(this._selected):-1}_actionSelected(e){var t;if(this.dispatchEvent(new CustomEvent("selected",{detail:{search:this._search,action:e},bubbles:!0,composed:!0})),!!e){if(e.children&&((t=e.children)===null||t===void 0?void 0:t.length)>0&&(this._currentRoot=e.id,this._search=""),this._headerRef.value.setSearch(""),this._headerRef.value.focusSearch(),e.handler){const i=e.handler(e);i!=null&&i.keepOpen||this.close()}this._bump=!0}}async _handleInput(e){this._search=e.detail.search,await this.updateComplete,this.dispatchEvent(new CustomEvent("change",{detail:{search:this._search,actions:this._actionMatches},bubbles:!0,composed:!0}))}_overlayClick(e){var t;!((t=e.target)===null||t===void 0)&&t.classList.contains("modal")&&this.close()}};C.styles=[Ki];S([E({type:String})],C.prototype,"placeholder",void 0);S([E({type:Boolean})],C.prototype,"disableHotkeys",void 0);S([E({type:Boolean})],C.prototype,"hideBreadcrumbs",void 0);S([E()],C.prototype,"openHotkey",void 0);S([E()],C.prototype,"navigationUpHotkey",void 0);S([E()],C.prototype,"navigationDownHotkey",void 0);S([E()],C.prototype,"closeHotkey",void 0);S([E()],C.prototype,"goBackHotkey",void 0);S([E()],C.prototype,"selectHotkey",void 0);S([E({type:Boolean})],C.prototype,"hotKeysJoinedView",void 0);S([E({type:Boolean})],C.prototype,"noAutoLoadMdIcons",void 0);S([E({type:Array,hasChanged(){return!0}})],C.prototype,"data",void 0);S([Y()],C.prototype,"visible",void 0);S([Y()],C.prototype,"_bump",void 0);S([Y()],C.prototype,"_actionMatches",void 0);S([Y()],C.prototype,"_search",void 0);S([Y()],C.prototype,"_currentRoot",void 0);S([Y()],C.prototype,"_flatData",void 0);S([Y()],C.prototype,"breadcrumbs",null);S([Y()],C.prototype,"_selected",void 0);C=S([ke("ninja-keys")],C);const Pt='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 2A2.25 2.25 0 0 1 22 4.25v5.462a3.25 3.25 0 0 1-.952 2.298l-8.5 8.503a3.255 3.255 0 0 1-4.597.001L3.489 16.06a3.25 3.25 0 0 1-.003-4.596l8.5-8.51A3.25 3.25 0 0 1 14.284 2h5.465Zm0 1.5h-5.465c-.465 0-.91.185-1.239.513l-8.512 8.523a1.75 1.75 0 0 0 .015 2.462l4.461 4.454a1.755 1.755 0 0 0 2.477 0l8.5-8.503a1.75 1.75 0 0 0 .513-1.237V4.25a.75.75 0 0 0-.75-.75ZM17 5.502a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Z" fill="currentColor"/></svg>',zi='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12.92 3.316c.806-.717 2.08-.145 2.08.934v15.496c0 1.078-1.274 1.65-2.08.934l-4.492-3.994a.75.75 0 0 0-.498-.19H4.25A2.25 2.25 0 0 1 2 14.247V9.75a2.25 2.25 0 0 1 2.25-2.25h3.68a.75.75 0 0 0 .498-.19l4.491-3.993Zm.58 1.49L9.425 8.43A2.25 2.25 0 0 1 7.93 9H4.25a.75.75 0 0 0-.75.75v4.497c0 .415.336.75.75.75h3.68a2.25 2.25 0 0 1 1.495.57l4.075 3.623V4.807ZM16.22 9.22a.75.75 0 0 1 1.06 0L19 10.94l1.72-1.72a.75.75 0 1 1 1.06 1.06L20.06 12l1.72 1.72a.75.75 0 1 1-1.06 1.06L19 13.06l-1.72 1.72a.75.75 0 1 1-1.06-1.06L17.94 12l-1.72-1.72a.75.75 0 0 1 0-1.06Z" fill="currentColor"/></svg>',Fi='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M15 4.25c0-1.079-1.274-1.65-2.08-.934L8.427 7.309a.75.75 0 0 1-.498.19H4.25A2.25 2.25 0 0 0 2 9.749v4.497a2.25 2.25 0 0 0 2.25 2.25h3.68a.75.75 0 0 1 .498.19l4.491 3.994c.806.716 2.081.144 2.081-.934V4.25ZM9.425 8.43 13.5 4.807v14.382l-4.075-3.624a2.25 2.25 0 0 0-1.495-.569H4.25a.75.75 0 0 1-.75-.75V9.75a.75.75 0 0 1 .75-.75h3.68a2.25 2.25 0 0 0 1.495-.569ZM18.992 5.897a.75.75 0 0 1 1.049.157A9.959 9.959 0 0 1 22 12a9.96 9.96 0 0 1-1.96 5.946.75.75 0 0 1-1.205-.892A8.459 8.459 0 0 0 20.5 12a8.459 8.459 0 0 0-1.665-5.054.75.75 0 0 1 .157-1.049Z" fill="#212121"/><path d="M17.143 8.37a.75.75 0 0 1 1.017.302c.536.99.84 2.125.84 3.328a6.973 6.973 0 0 1-.84 3.328.75.75 0 0 1-1.32-.714c.42-.777.66-1.666.66-2.614s-.24-1.837-.66-2.614a.75.75 0 0 1 .303-1.017Z" fill="currentColor"/></svg>',Zt='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 2A2.25 2.25 0 0 1 22 4.25v5.462a3.25 3.25 0 0 1-.952 2.298l-.026.026a6.473 6.473 0 0 0-1.43-.692l.395-.395a1.75 1.75 0 0 0 .513-1.237V4.25a.75.75 0 0 0-.75-.75h-5.466c-.464 0-.91.185-1.238.513l-8.512 8.523a1.75 1.75 0 0 0 .015 2.462l4.461 4.454a1.755 1.755 0 0 0 2.33.13c.165.487.386.947.654 1.374a3.256 3.256 0 0 1-4.043-.442L3.489 16.06a3.25 3.25 0 0 1-.004-4.596l8.5-8.51a3.25 3.25 0 0 1 2.3-.953h5.465ZM17 5.502a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM17.5 23a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11Zm-2.354-7.854a.5.5 0 0 1 .708 0l1.646 1.647 1.646-1.647a.5.5 0 0 1 .708.708L18.207 17.5l1.647 1.646a.5.5 0 0 1-.708.708L17.5 18.207l-1.646 1.647a.5.5 0 0 1-.708-.708l1.647-1.646-1.647-1.646a.5.5 0 0 1 0-.708Z" fill="currentColor"/></svg>',mn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.25 2a.75.75 0 0 0-.743.648l-.007.102v5.69l-4.574-4.56a6.41 6.41 0 0 0-8.878-.179l-.186.18a6.41 6.41 0 0 0 0 9.063l8.845 8.84a.75.75 0 0 0 1.06-1.062l-8.845-8.838a4.91 4.91 0 0 1 6.766-7.112l.178.17L17.438 9.5H11.75a.75.75 0 0 0-.743.648L11 10.25c0 .38.282.694.648.743l.102.007h7.5a.75.75 0 0 0 .743-.648L20 10.25v-7.5a.75.75 0 0 0-.75-.75Z" fill="currentColor"/></svg>',Nn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 2c5.523 0 10 4.477 10 10s-4.477 10-10 10S2 17.523 2 12 6.477 2 12 2Zm0 1.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17Zm-1.25 9.94 4.47-4.47a.75.75 0 0 1 1.133.976l-.073.084-5 5a.75.75 0 0 1-.976.073l-.084-.073-2.5-2.5a.75.75 0 0 1 .976-1.133l.084.073 1.97 1.97 4.47-4.47-4.47 4.47Z" fill="currentColor"/></svg>',Yi='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 11.5a.75.75 0 0 1 .743.648l.007.102v5a4.75 4.75 0 0 1-4.533 4.745L15.75 22h-7.5c-.98 0-1.813-.626-2.122-1.5h9.622l.184-.005a3.25 3.25 0 0 0 3.06-3.06L19 17.25v-5a.75.75 0 0 1 .75-.75Zm-2.5-2a.75.75 0 0 1 .743.648l.007.102v7a2.25 2.25 0 0 1-2.096 2.245l-.154.005h-10a2.25 2.25 0 0 1-2.245-2.096L3.5 17.25v-7a.75.75 0 0 1 1.493-.102L5 10.25v7c0 .38.282.694.648.743L5.75 18h10a.75.75 0 0 0 .743-.648l.007-.102v-7a.75.75 0 0 1 .75-.75ZM6.218 6.216l3.998-3.996a.75.75 0 0 1 .976-.073l.084.072 4.004 3.997a.75.75 0 0 1-.976 1.134l-.084-.073-2.72-2.714v9.692a.75.75 0 0 1-.648.743l-.102.007a.75.75 0 0 1-.743-.648L10 14.255V4.556L7.279 7.277a.75.75 0 0 1-.977.072l-.084-.072a.75.75 0 0 1-.072-.977l.072-.084 3.998-3.996-3.998 3.996Z" fill="currentColor"/></svg>',Be='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 2c5.523 0 10 4.478 10 10s-4.477 10-10 10S2 17.522 2 12S6.477 2 12 2Zm0 1.667c-4.595 0-8.333 3.738-8.333 8.333c0 4.595 3.738 8.333 8.333 8.333c4.595 0 8.333-3.738 8.333-8.333c0-4.595-3.738-8.333-8.333-8.333ZM11.25 6a.75.75 0 0 1 .743.648L12 6.75V12h3.25a.75.75 0 0 1 .102 1.493l-.102.007h-4a.75.75 0 0 1-.743-.648l-.007-.102v-6a.75.75 0 0 1 .75-.75Z" fill="currentColor"/></svg>',Vt='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M17.5 12a5.5 5.5 0 1 1 0 11 5.5 5.5 0 0 1 0-11Zm0 2-.09.007a.5.5 0 0 0-.402.402L17 14.5V17L14.498 17l-.09.008a.5.5 0 0 0-.402.402l-.008.09.008.09a.5.5 0 0 0 .402.402l.09.008H17v2.503l.008.09a.5.5 0 0 0 .402.402l.09.008.09-.008a.5.5 0 0 0 .402-.402l.008-.09V18l2.504.001.09-.008a.5.5 0 0 0 .402-.402l.008-.09-.008-.09a.5.5 0 0 0-.403-.402l-.09-.008H18v-2.5l-.008-.09a.5.5 0 0 0-.402-.403L17.5 14Zm-3.246-4c.835 0 1.563.454 1.951 1.13a6.44 6.44 0 0 0-1.518.509.736.736 0 0 0-.433-.139H9.752a.75.75 0 0 0-.75.75v4.249c0 1.41.974 2.594 2.286 2.915a6.42 6.42 0 0 0 .735 1.587l-.02-.001a4.501 4.501 0 0 1-4.501-4.501V12.25A2.25 2.25 0 0 1 9.752 10h4.502Zm-6.848 0a3.243 3.243 0 0 0-.817 1.5H4.25a.75.75 0 0 0-.75.75v2.749a2.501 2.501 0 0 0 3.082 2.433c.085.504.24.985.453 1.432A4.001 4.001 0 0 1 2 14.999V12.25a2.25 2.25 0 0 1 2.096-2.245L4.25 10h3.156Zm12.344 0A2.25 2.25 0 0 1 22 12.25v.56A6.478 6.478 0 0 0 17.5 11l-.245.005A3.21 3.21 0 0 0 16.6 10h3.15ZM18.5 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5ZM12 3a3 3 0 1 1 0 6 3 3 0 0 1 0-6ZM5.5 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Zm13 1.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2Zm-6.5-1a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3Zm-6.5 1a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z" fill="currentColor"/></svg>',Wi='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 20 20"><path fill="currentColor" d="M9.562 3.262a.5.5 0 0 1 .879 0l6.5 12a.5.5 0 0 1-.44.739H3.5a.5.5 0 0 1-.44-.739l6.503-12Zm1.758-.477c-.567-1.047-2.07-1.047-2.638 0L2.18 14.786a1.5 1.5 0 0 0 1.32 2.215h13.002a1.5 1.5 0 0 0 1.319-2.215l-6.5-12ZM10.5 7.5a.5.5 0 1 0-1 0v4a.5.5 0 0 0 1 0v-4Zm.25 6.25a.75.75 0 1 1-1.5 0a.75.75 0 0 1 1.5 0Z"/></svg>',Xi=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#FFEBEE"/>
<path d="M8 8.5C8 7.94772 8.44772 7.5 9 7.5C9.55228 7.5 10 7.94772 10 8.5V13C10 13.5523 9.55228 14 9 14C8.44772 14 8 13.5523 8 13V8.5Z" fill="#FF382D"/>
<path d="M8 15.5C8 14.9477 8.44772 14.5 9 14.5C9.55228 14.5 10 14.9477 10 15.5C10 16.0523 9.55228 16.5 9 16.5C8.44772 16.5 8 16.0523 8 15.5Z" fill="#FF382D"/>
<path d="M11 8.5C11 7.94772 11.4477 7.5 12 7.5C12.5523 7.5 13 7.94772 13 8.5V13C13 13.5523 12.5523 14 12 14C11.4477 14 11 13.5523 11 13V8.5Z" fill="#FF382D"/>
<path d="M11 15.5C11 14.9477 11.4477 14.5 12 14.5C12.5523 14.5 13 14.9477 13 15.5C13 16.0523 12.5523 16.5 12 16.5C11.4477 16.5 11 16.0523 11 15.5Z" fill="#FF382D"/>
<path d="M14 8.5C14 7.94772 14.4477 7.5 15 7.5C15.5523 7.5 16 7.94772 16 8.5V13C16 13.5523 15.5523 14 15 14C14.4477 14 14 13.5523 14 13V8.5Z" fill="#FF382D"/>
<path d="M14 15.5C14 14.9477 14.4477 14.5 15 14.5C15.5523 14.5 16 14.9477 16 15.5C16 16.0523 15.5523 16.5 15 16.5C14.4477 16.5 14 16.0523 14 15.5Z" fill="#FF382D"/>
</svg>
`,Ji=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M9.7642 8L9.62358 14.1619H8.25142L8.11506 8H9.7642ZM8.9375 16.821C8.67898 16.821 8.45739 16.7301 8.27273 16.5483C8.09091 16.3665 8 16.1449 8 15.8835C8 15.6278 8.09091 15.4091 8.27273 15.2273C8.45739 15.0455 8.67898 14.9545 8.9375 14.9545C9.19034 14.9545 9.40909 15.0455 9.59375 15.2273C9.78125 15.4091 9.875 15.6278 9.875 15.8835C9.875 16.0568 9.83097 16.2145 9.7429 16.3565C9.65767 16.4986 9.54403 16.6122 9.40199 16.6974C9.26278 16.7798 9.10795 16.821 8.9375 16.821Z" fill="#446888"/>
<path d="M13.1073 8L12.9667 14.1619H11.5945L11.4582 8H13.1073ZM12.2806 16.821C12.0221 16.821 11.8005 16.7301 11.6159 16.5483C11.434 16.3665 11.3431 16.1449 11.3431 15.8835C11.3431 15.6278 11.434 15.4091 11.6159 15.2273C11.8005 15.0455 12.0221 14.9545 12.2806 14.9545C12.5335 14.9545 12.7522 15.0455 12.9369 15.2273C13.1244 15.4091 13.2181 15.6278 13.2181 15.8835C13.2181 16.0568 13.1741 16.2145 13.086 16.3565C13.0008 16.4986 12.8872 16.6122 12.7451 16.6974C12.6059 16.7798 12.4511 16.821 12.2806 16.821Z" fill="#446888"/>
<path d="M16.4505 8L16.3098 14.1619H14.9377L14.8013 8H16.4505ZM15.6237 16.821C15.3652 16.821 15.1436 16.7301 14.959 16.5483C14.7772 16.3665 14.6862 16.1449 14.6862 15.8835C14.6862 15.6278 14.7772 15.4091 14.959 15.2273C15.1436 15.0455 15.3652 14.9545 15.6237 14.9545C15.8766 14.9545 16.0953 15.0455 16.28 15.2273C16.4675 15.4091 16.5612 15.6278 16.5612 15.8835C16.5612 16.0568 16.5172 16.2145 16.4291 16.3565C16.3439 16.4986 16.2303 16.6122 16.0882 16.6974C15.949 16.7798 15.7942 16.821 15.6237 16.821Z" fill="#446888"/>
</svg>`,qi=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M10.7642 8L10.6236 14.1619H9.25142L9.11506 8H10.7642ZM9.9375 16.821C9.67898 16.821 9.45739 16.7301 9.27273 16.5483C9.09091 16.3665 9 16.1449 9 15.8835C9 15.6278 9.09091 15.4091 9.27273 15.2273C9.45739 15.0455 9.67898 14.9545 9.9375 14.9545C10.1903 14.9545 10.4091 15.0455 10.5938 15.2273C10.7812 15.4091 10.875 15.6278 10.875 15.8835C10.875 16.0568 10.831 16.2145 10.7429 16.3565C10.6577 16.4986 10.544 16.6122 10.402 16.6974C10.2628 16.7798 10.108 16.821 9.9375 16.821Z" fill="#446888"/>
<path d="M14.1073 8L13.9667 14.1619H12.5945L12.4582 8H14.1073ZM13.2806 16.821C13.0221 16.821 12.8005 16.7301 12.6159 16.5483C12.434 16.3665 12.3431 16.1449 12.3431 15.8835C12.3431 15.6278 12.434 15.4091 12.6159 15.2273C12.8005 15.0455 13.0221 14.9545 13.2806 14.9545C13.5335 14.9545 13.7522 15.0455 13.9369 15.2273C14.1244 15.4091 14.2181 15.6278 14.2181 15.8835C14.2181 16.0568 14.1741 16.2145 14.086 16.3565C14.0008 16.4986 13.8872 16.6122 13.7451 16.6974C13.6059 16.7798 13.4511 16.821 13.2806 16.821Z" fill="#446888"/>
</svg>`,Qi=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M12.7642 8L12.6236 14.1619H11.2514L11.1151 8H12.7642ZM11.9375 16.821C11.679 16.821 11.4574 16.7301 11.2727 16.5483C11.0909 16.3665 11 16.1449 11 15.8835C11 15.6278 11.0909 15.4091 11.2727 15.2273C11.4574 15.0455 11.679 14.9545 11.9375 14.9545C12.1903 14.9545 12.4091 15.0455 12.5938 15.2273C12.7812 15.4091 12.875 15.6278 12.875 15.8835C12.875 16.0568 12.831 16.2145 12.7429 16.3565C12.6577 16.4986 12.544 16.6122 12.402 16.6974C12.2628 16.7798 12.108 16.821 11.9375 16.821Z" fill="#446888"/>
</svg>`,eo=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M13.5686 8L11.1579 16.9562H10L12.4107 8H13.5686Z" fill="#446888"/>
</svg>`,fe='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="m13.314 7.565l-.136.126l-10.48 10.488a2.27 2.27 0 0 0 3.211 3.208L16.388 10.9a2.251 2.251 0 0 0-.001-3.182l-.157-.146a2.25 2.25 0 0 0-2.916-.007Zm-.848 2.961l1.088 1.088l-8.706 8.713a.77.77 0 1 1-1.089-1.088l8.707-8.713Zm4.386 4.48L16.75 15a.75.75 0 0 0-.743.648L16 15.75v.75h-.75a.75.75 0 0 0-.743.648l-.007.102c0 .38.282.694.648.743l.102.007H16v.75c0 .38.282.694.648.743l.102.007a.75.75 0 0 0 .743-.648l.007-.102V18h.75a.75.75 0 0 0 .743-.648L19 17.25a.75.75 0 0 0-.648-.743l-.102-.007h-.75v-.75a.75.75 0 0 0-.648-.743L16.75 15l.102.007Zm-1.553-6.254l.027.027a.751.751 0 0 1 0 1.061l-.711.713l-1.089-1.089l.73-.73a.75.75 0 0 1 1.043.018ZM6.852 5.007L6.75 5a.75.75 0 0 0-.743.648L6 5.75v.75h-.75a.75.75 0 0 0-.743.648L4.5 7.25c0 .38.282.693.648.743L5.25 8H6v.75c0 .38.282.693.648.743l.102.007a.75.75 0 0 0 .743-.648L7.5 8.75V8h.75a.75.75 0 0 0 .743-.648L9 7.25a.75.75 0 0 0-.648-.743L8.25 6.5H7.5v-.75a.75.75 0 0 0-.648-.743L6.75 5l.102.007Zm12-2L18.75 3a.75.75 0 0 0-.743.648L18 3.75v.75h-.75a.75.75 0 0 0-.743.648l-.007.102c0 .38.282.693.648.743L17.25 6H18v.75c0 .38.282.693.648.743l.102.007a.75.75 0 0 0 .743-.648l.007-.102V6h.75a.75.75 0 0 0 .743-.648L21 5.25a.75.75 0 0 0-.648-.743L20.25 4.5h-.75v-.75a.75.75 0 0 0-.648-.743L18.75 3l.102.007Z" fill="currentColor"/></svg>',to='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H18a2.5 2.5 0 0 1 2.5 2.5v14.25a.75.75 0 0 1-.75.75H5.5a1 1 0 0 0 1 1h13.25a.75.75 0 0 1 0 1.5H6.5A2.5 2.5 0 0 1 4 19.5v-15ZM5.5 18H19V4.5a1 1 0 0 0-1-1H6.5a1 1 0 0 0-1 1V18Z" fill="currentColor"/></svg>',no='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M6.75 19.5h14.5a.75.75 0 0 0 .102-1.493L21.25 18H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm0-15h14.5a.75.75 0 0 0 .102-1.493L21.25 3H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm7 3.5a.75.75 0 0 0 0 1.5h7.5a.75.75 0 0 0 0-1.5h-7.5ZM13 13.75a.75.75 0 0 1 .75-.75h7.5a.75.75 0 0 1 0 1.5h-7.5a.75.75 0 0 1-.75-.75Zm-2-2.25a4.5 4.5 0 1 1-9 0a4.5 4.5 0 0 1 9 0Zm-4-2a.5.5 0 0 0-1 0V11H4.5a.5.5 0 0 0 0 1H6v1.5a.5.5 0 0 0 1 0V12h1.5a.5.5 0 0 0 0-1H7V9.5Z" fill="currentColor"/></svg>',io='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M6.75 4.5h14.5a.75.75 0 0 0 .102-1.493L21.25 3H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm0 15h14.5a.75.75 0 0 0 .102-1.493L21.25 18H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm7-11.5a.75.75 0 0 0 0 1.5h7.5a.75.75 0 0 0 0-1.5h-7.5ZM13 13.75a.75.75 0 0 1 .75-.75h7.5a.75.75 0 0 1 0 1.5h-7.5a.75.75 0 0 1-.75-.75Zm-2-2.25a4.5 4.5 0 1 1-9 0a4.5 4.5 0 0 1 9 0Zm-2 0a.5.5 0 0 0-.5-.5h-4a.5.5 0 0 0 0 1h4a.5.5 0 0 0 .5-.5Z" fill="currentColor"/></svg>',oo='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M3 17h7.522l-2 2H3a1 1 0 0 1-.117-1.993L3 17Zm0-2h7.848a1.75 1.75 0 0 1-.775-2H3l-.117.007A1 1 0 0 0 3 15Zm0-8h18l.117-.007A1 1 0 0 0 21 5H3l-.117.007A1 1 0 0 0 3 7Zm9.72 9.216a.75.75 0 1 1 1.06 1.06l-4.5 4.5a.75.75 0 1 1-1.06-1.06l4.5-4.5ZM3 9h10a1 1 0 0 1 .117 1.993L13 11H3a1 1 0 0 1-.117-1.993L3 9Zm13.5-1a.75.75 0 0 1 .744.658l.14 1.13a3.25 3.25 0 0 0 2.828 2.829l1.13.139a.75.75 0 0 1 0 1.488l-1.13.14a3.25 3.25 0 0 0-2.829 2.828l-.139 1.13a.75.75 0 0 1-1.488 0l-.14-1.13a3.25 3.25 0 0 0-2.828-2.829l-1.13-.139a.75.75 0 0 1 0-1.488l1.13-.14a3.25 3.25 0 0 0 2.829-2.828l.139-1.13A.75.75 0 0 1 16.5 8Z" fill="currentColor"/></svg>',so='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18"viewBox="0 0 24 24"><path fill="currentColor" d="M3.839 5.858c2.94-3.916 9.03-5.055 13.364-2.36c4.28 2.66 5.854 7.777 4.1 12.577c-1.655 4.533-6.016 6.328-9.159 4.048c-1.177-.854-1.634-1.925-1.854-3.664l-.106-.987l-.045-.398c-.123-.934-.311-1.352-.705-1.572c-.535-.298-.892-.305-1.595-.033l-.351.146l-.179.078c-1.014.44-1.688.595-2.541.416l-.2-.047l-.164-.047c-2.789-.864-3.202-4.647-.565-8.157Zm.984 6.716l.123.037l.134.03c.439.087.814.015 1.437-.242l.602-.257c1.202-.493 1.985-.54 3.046.05c.917.512 1.275 1.298 1.457 2.66l.053.459l.055.532l.047.422c.172 1.361.485 2.09 1.248 2.644c2.275 1.65 5.534.309 6.87-3.349c1.516-4.152.174-8.514-3.484-10.789c-3.675-2.284-8.899-1.306-11.373 1.987c-2.075 2.763-1.82 5.28-.215 5.816Zm11.225-1.994a1.25 1.25 0 1 1 2.414-.647a1.25 1.25 0 0 1-2.414.647Zm.494 3.488a1.25 1.25 0 1 1 2.415-.647a1.25 1.25 0 0 1-2.415.647ZM14.07 7.577a1.25 1.25 0 1 1 2.415-.647a1.25 1.25 0 0 1-2.415.647Zm-.028 8.998a1.25 1.25 0 1 1 2.414-.647a1.25 1.25 0 0 1-2.414.647Zm-3.497-9.97a1.25 1.25 0 1 1 2.415-.646a1.25 1.25 0 0 1-2.415.646Z"/></svg>',ao='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 12 2Zm5 10a5 5 0 1 1-10 0a5 5 0 0 1 10 0Zm4.25.75a.75.75 0 0 0 0-1.5h-1.5a.75.75 0 0 0 0 1.5h1.5ZM12 19a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 12 19Zm-7.75-6.25a.75.75 0 0 0 0-1.5h-1.5a.75.75 0 0 0 0 1.5h1.5Zm-.03-8.53a.75.75 0 0 1 1.06 0l1.5 1.5a.75.75 0 0 1-1.06 1.06l-1.5-1.5a.75.75 0 0 1 0-1.06Zm1.06 15.56a.75.75 0 1 1-1.06-1.06l1.5-1.5a.75.75 0 1 1 1.06 1.06l-1.5 1.5Zm14.5-15.56a.75.75 0 0 0-1.06 0l-1.5 1.5a.75.75 0 0 0 1.06 1.06l1.5-1.5a.75.75 0 0 0 0-1.06Zm-1.06 15.56a.75.75 0 1 0 1.06-1.06l-1.5-1.5a.75.75 0 1 0-1.06 1.06l1.5 1.5Z"/></svg>',ro='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M20.026 17.001c-2.762 4.784-8.879 6.423-13.663 3.661A9.965 9.965 0 0 1 3.13 17.68a.75.75 0 0 1 .365-1.132c3.767-1.348 5.785-2.91 6.956-5.146c1.232-2.353 1.551-4.93.689-8.463a.75.75 0 0 1 .769-.927a9.961 9.961 0 0 1 4.457 1.327c4.784 2.762 6.423 8.879 3.66 13.662Zm-8.248-4.903c-1.25 2.389-3.31 4.1-6.817 5.499a8.49 8.49 0 0 0 2.152 1.766a8.502 8.502 0 0 0 8.502-14.725a8.484 8.484 0 0 0-2.792-1.015c.647 3.384.23 6.043-1.045 8.475Z"/></svg>',lo='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M4.25 3A2.25 2.25 0 0 0 2 5.25v10.5A2.25 2.25 0 0 0 4.25 18H9.5v1.25c0 .69-.56 1.25-1.25 1.25h-.5a.75.75 0 0 0 0 1.5h8.5a.75.75 0 0 0 0-1.5h-.5c-.69 0-1.25-.56-1.25-1.25V18h5.25A2.25 2.25 0 0 0 22 15.75V5.25A2.25 2.25 0 0 0 19.75 3H4.25ZM13 18v1.25c0 .45.108.875.3 1.25h-2.6c.192-.375.3-.8.3-1.25V18h2ZM3.5 5.25a.75.75 0 0 1 .75-.75h15.5a.75.75 0 0 1 .75.75V13h-17V5.25Zm0 9.25h17v1.25a.75.75 0 0 1-.75.75H4.25a.75.75 0 0 1-.75-.75V14.5Z"/></svg>',se='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M12 3.5c-3.104 0-6 2.432-6 6.25v4.153L4.682 17h14.67l-1.354-3.093V11.75a.75.75 0 0 1 1.5 0v1.843l1.381 3.156a1.25 1.25 0 0 1-1.145 1.751H15a3.002 3.002 0 0 1-6.003 0H4.305a1.25 1.25 0 0 1-1.15-1.739l1.344-3.164V9.75C4.5 5.068 8.103 2 12 2c.86 0 1.705.15 2.5.432a.75.75 0 0 1-.502 1.413A5.964 5.964 0 0 0 12 3.5ZM12 20c.828 0 1.5-.671 1.501-1.5h-3.003c0 .829.673 1.5 1.502 1.5Zm3.25-13h-2.5l-.101.007A.75.75 0 0 0 12.75 8.5h1.043l-1.653 2.314l-.055.09A.75.75 0 0 0 12.75 12h2.5l.102-.007a.75.75 0 0 0-.102-1.493h-1.042l1.653-2.314l.055-.09A.75.75 0 0 0 15.25 7Zm6-5h-3.5l-.101.007A.75.75 0 0 0 17.75 3.5h2.134l-2.766 4.347l-.05.09A.75.75 0 0 0 17.75 9h3.5l.102-.007A.75.75 0 0 0 21.25 7.5h-2.133l2.766-4.347l.05-.09A.75.75 0 0 0 21.25 2Z"/></svg>',st='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11"/></g></svg>',Ut='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092a10 10 0 1 0-4.777-4.719"/></svg>',co='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 2v2M7 22v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2M8 2v2"/><circle cx="12" cy="11" r="3"/><rect width="18" height="18" x="3" y="4" rx="2"/></g></svg>',Gt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2m16 0h2m-7-1v2m-6-2v2"/></g></svg>',ho='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233a14 14 0 0 0 6.392 6.384"/></svg>',uo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M11 6a13 13 0 0 0 8.4-2.8A1 1 0 0 1 21 4v12a1 1 0 0 1-1.6.8A13 13 0 0 0 11 14H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/><path d="M6 14a12 12 0 0 0 2.4 7.2a2 2 0 0 0 3.2-2.4A8 8 0 0 1 10 14M8 6v8"/></g></svg>',po='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="8" height="18" x="3" y="3" rx="1"/><path d="M7 3v18m13.4-2.1c.2.5-.1 1.1-.6 1.3l-1.9.7c-.5.2-1.1-.1-1.3-.6L11.1 5.1c-.2-.5.1-1.1.6-1.3l1.9-.7c.5-.2 1.1.1 1.3.6Z"/></g></svg>',_o='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M7 16c.5-2 1.5-7 4-7c2 0 2 3 4 3c2.5 0 4.5-5 5-7"/></g></svg>',Kt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="12" cy="10" r="3"/><path d="M7 21v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2"/></g></svg>',zt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 3.128a4 4 0 0 1 0 7.744M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/></g></svg>',Ft='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M13.172 2a2 2 0 0 1 1.414.586l6.71 6.71a2.4 2.4 0 0 1 0 3.408l-4.592 4.592a2.4 2.4 0 0 1-3.408 0l-6.71-6.71A2 2 0 0 1 6 9.172V3a1 1 0 0 1 1-1zM2 7v6.172a2 2 0 0 0 .586 1.414l6.71 6.71a2.4 2.4 0 0 0 3.191.193"/><circle cx="10.5" cy="6.5" r=".5" fill="currentColor"/></g></svg>',vo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m16 18l6-6l-6-6M8 6l-6 6l6 6"/></svg>',fo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="m17 2l4 4l-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4l4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/></g></svg>',_t='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="12" x="3" y="8" rx="1"/><path d="M10 8V5c0-.6-.4-1-1-1H6a1 1 0 0 0-1 1v3m14 0V5c0-.6-.4-1-1-1h-3a1 1 0 0 0-1 1v3"/></g></svg>',go='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M14 14a2 2 0 0 0 2-2V8h-2"/><path d="M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z"/><path d="M8 14a2 2 0 0 0 2-2V8H8"/></g></svg>',Oo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M10 22V7a1 1 0 0 0-1-1H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5a1 1 0 0 0-1-1H2"/><rect width="8" height="8" x="14" y="2" rx="1"/></g></svg>',Yt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/></g></svg>',Wt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 6v6l4 2m4-2v5m0 4h.01"/><path d="M21.25 8.2A10 10 0 1 0 16 21.16"/></g></svg>',Ao='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><path d="M2 10h20"/></g></svg>',mo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M11.5 15H7a4 4 0 0 0-4 4v2m18.378-4.374a1 1 0 0 0-3.004-3.004l-4.01 4.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z"/><circle cx="10" cy="7" r="4"/></g></svg>',No='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2s4-2 4-2M9 9h.01M15 9h.01"/></g></svg>',Co='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="7" x="3" y="3" rx="1"/><rect width="9" height="7" x="3" y="14" rx="1"/><rect width="5" height="7" x="16" y="14" rx="1"/></g></svg>',Mo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/></g></svg>',So=n=>[{key:"light",label:n("COMMAND_BAR.COMMANDS.LIGHT_MODE"),icon:ao},{key:"dark",label:n("COMMAND_BAR.COMMANDS.DARK_MODE"),icon:ro},{key:"auto",label:n("COMMAND_BAR.COMMANDS.SYSTEM_MODE"),icon:lo}],wo=n=>{qn.set(ei.COLOR_SCHEME,n);const e=window.matchMedia("(prefers-color-scheme: dark)").matches;jn(e)};function Eo(){const{t:n}=oe(),e=O(()=>So(n));return{goToAppearanceHotKeys:O(()=>{const i=e.value.map(o=>({id:o.key,title:o.label,parent:"appearance_settings",section:n("COMMAND_BAR.SECTIONS.APPEARANCE"),icon:o.icon,handler:()=>{wo(o.key)}}));return[{id:"appearance_settings",title:n("COMMAND_BAR.COMMANDS.CHANGE_APPEARANCE"),section:n("COMMAND_BAR.SECTIONS.APPEARANCE"),icon:so,children:i.map(o=>o.id)},...i]})}}const D=z.SNOOZE_OPTIONS,_e=n=>()=>H.emit(qt,n),yo=[{id:"snooze_notification",title:"COMMAND_BAR.COMMANDS.SNOOZE_NOTIFICATION",icon:se,children:Object.values(D)},{id:D.AN_HOUR_FROM_NOW,title:"COMMAND_BAR.COMMANDS.AN_HOUR_FROM_NOW",parent:"snooze_notification",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",icon:se,handler:_e(D.AN_HOUR_FROM_NOW)},{id:D.UNTIL_TOMORROW,title:"COMMAND_BAR.COMMANDS.UNTIL_TOMORROW",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:se,handler:_e(D.UNTIL_TOMORROW)},{id:D.UNTIL_NEXT_WEEK,title:"COMMAND_BAR.COMMANDS.UNTIL_NEXT_WEEK",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:se,handler:_e(D.UNTIL_NEXT_WEEK)},{id:D.UNTIL_NEXT_MONTH,title:"COMMAND_BAR.COMMANDS.UNTIL_NEXT_MONTH",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:se,handler:_e(D.UNTIL_NEXT_MONTH)},{id:D.UNTIL_CUSTOM_TIME,title:"COMMAND_BAR.COMMANDS.UNTIL_CUSTOM_TIME",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:se,handler:_e(D.UNTIL_CUSTOM_TIME)}];function To(){const{t:n}=oe(),e=gt(),t=o=>o.map(s=>({...s,title:n(s.title),section:s.section?n(s.section):void 0}));return{inboxHotKeys:O(()=>ft(e.name)?t(yo):[])}}const q="COMMAND_BAR.SECTIONS.GENERAL",Z="COMMAND_BAR.SECTIONS.REPORTS",R="COMMAND_BAR.SECTIONS.SETTINGS",Io=[{id:"goto_my_inbox",title:"COMMAND_BAR.COMMANDS.GO_TO_MY_INBOX",section:q,icon:st,routeName:"inbox_view"},{id:"goto_conversation_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_DASHBOARD",section:q,icon:Ut,routeName:"home"},{id:"goto_contacts_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CONTACTS_DASHBOARD",section:q,icon:co,routeName:"contacts_dashboard_index"},{id:"goto_captain",title:"COMMAND_BAR.COMMANDS.GO_TO_CAPTAIN",section:q,icon:Gt,routeName:"captain_assistants_index",params:{navigationPath:"captain_assistants_overview_index"}},{id:"goto_calls_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CALLS_DASHBOARD",section:q,icon:ho,routeName:"calls_dashboard_index"},{id:"goto_campaigns",title:"COMMAND_BAR.COMMANDS.GO_TO_CAMPAIGNS",section:q,icon:uo,routeName:"campaigns_livechat_index"},{id:"goto_help_center",title:"COMMAND_BAR.COMMANDS.GO_TO_HELP_CENTER",section:q,icon:po,routeName:"portals_index",params:{navigationPath:"portals_articles_index"}},{id:"open_reports_overview",title:"COMMAND_BAR.COMMANDS.GO_TO_REPORTS_OVERVIEW",section:Z,icon:_o,routeName:"account_overview_reports"},{id:"open_conversation_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_REPORTS",section:Z,icon:Ut,routeName:"conversation_reports"},{id:"open_agent_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_AGENT_REPORTS",section:Z,icon:Kt,routeName:"agent_reports_index"},{id:"open_label_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_LABEL_REPORTS",section:Z,icon:Ft,routeName:"label_reports_index"},{id:"open_inbox_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_INBOX_REPORTS",section:Z,icon:st,routeName:"inbox_reports_index"},{id:"open_team_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_TEAM_REPORTS",section:Z,icon:zt,routeName:"team_reports_index"},{id:"open_csat_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_CSAT_REPORTS",section:Z,icon:No,routeName:"csat_reports"},{id:"open_bot_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_BOT_REPORTS",section:Z,icon:Gt,routeName:"bot_reports"},{id:"open_sla_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_SLA_REPORTS",section:Z,icon:Wt,routeName:"sla_reports"},{id:"open_agent_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AGENTS",section:R,icon:Kt,routeName:"agent_list"},{id:"open_team_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_TEAMS",section:R,icon:zt,routeName:"settings_teams_list"},{id:"open_inbox_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_INBOXES",section:R,icon:st,routeName:"settings_inbox_list"},{id:"open_template_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_TEMPLATES",section:R,icon:Co,routeName:"settings_templates"},{id:"open_label_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_LABELS",section:R,icon:Ft,routeName:"labels_list"},{id:"open_custom_attribute_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CUSTOM_ATTRIBUTES",section:R,icon:vo,routeName:"attributes_list"},{id:"open_automation_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AUTOMATION",section:R,icon:fo,routeName:"automation_list"},{id:"open_macro_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_MACROS",section:R,icon:_t,routeName:"macros_wrapper"},{id:"open_canned_response_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CANNED_RESPONSES",section:R,icon:go,routeName:"canned_list"},{id:"open_sla_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_SLA",section:R,icon:Wt,routeName:"sla_list"},{id:"open_applications_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_APPLICATIONS",section:R,icon:Oo,routeName:"settings_applications"},{id:"open_data_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_DATA",section:R,icon:Mo,routeName:"settings_data_imports"},{id:"open_audit_logs_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AUDIT_LOGS",section:R,icon:Yt,routeName:"auditlogs_list"},{id:"open_billing_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_BILLING",section:R,icon:Ao,routeName:"billing_settings_index"},{id:"open_account_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_ACCOUNT",section:R,icon:Yt,routeName:"general_settings_index"},{id:"open_profile_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_PROFILE",section:R,icon:mo,routeName:"profile_settings_index"}];function bo(n=Q(!1)){const{t:e}=oe(),t=Qn(),{checkPermissions:i,checkInstallationType:o,isFeatureFlagEnabled:s}=Qt(),a=G("getCurrentAccountId"),r=h=>t.resolve({name:h.routeName,params:{accountId:a.value,...h.params}}),l=h=>{const{meta:d}=h;return!s(d==null?void 0:d.featureFlag)||!i(d==null?void 0:d.permissions)||!o(d==null?void 0:d.installationTypes)?!1:!n.value||Dn(h.name)};return{goToCommandHotKeys:O(()=>Io.flatMap(h=>{const d=r(h);return l(d)?{id:h.id,section:e(h.section),title:e(h.title),icon:h.icon,handler:()=>t.push(d)}:[]}))}}const Cn=z.SNOOZE_OPTIONS,Ro=[{id:"resolve_conversation",title:"COMMAND_BAR.COMMANDS.RESOLVE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:Nn,handler:()=>H.emit(Pn)}],Mn=(n,e,t)=>Object.values(Cn).map(i=>({id:i,title:`COMMAND_BAR.COMMANDS.${i.toUpperCase()}`,parent:e,section:t,icon:Be,handler:()=>H.emit(n,i)})),Xt=[{id:"snooze_conversation",title:"COMMAND_BAR.COMMANDS.SNOOZE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:Be,children:Object.values(Cn)},...Mn(en,"snooze_conversation","COMMAND_BAR.SECTIONS.SNOOZE_CONVERSATION")],$o=[{id:"reopen_conversation",title:"COMMAND_BAR.COMMANDS.REOPEN_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:mn,handler:()=>H.emit(Zn)}],xo={id:"send_transcript",title:"COMMAND_BAR.COMMANDS.SEND_TRANSCRIPT",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:Yi,handler:()=>H.emit(Hn)},ko={id:"unmute_conversation",title:"COMMAND_BAR.COMMANDS.UNMUTE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:Fi,handler:()=>H.emit(Bn)},jo={id:"mute_conversation",title:"COMMAND_BAR.COMMANDS.MUTE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:zi,handler:()=>H.emit(Ln)},Do=z.SNOOZE_OPTIONS,Sn=n=>()=>H.emit(n),Bo=[{id:"bulk_action_snooze_conversation",title:"COMMAND_BAR.COMMANDS.SNOOZE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.BULK_ACTIONS",icon:Be,children:Object.values(Do)},...Mn(tn,"bulk_action_snooze_conversation","COMMAND_BAR.SECTIONS.BULK_ACTIONS")],Lo=[{id:"bulk_action_reopen_conversation",title:"COMMAND_BAR.COMMANDS.REOPEN_CONVERSATION",section:"COMMAND_BAR.SECTIONS.BULK_ACTIONS",icon:mn,handler:Sn(Vn)}],Ho=[{id:"bulk_action_resolve_conversation",title:"COMMAND_BAR.COMMANDS.RESOLVE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.BULK_ACTIONS",icon:Nn,handler:Sn(Un)}];function Po(){const{t:n}=oe(),e=G("bulkActions/getSelectedConversationIds"),t=o=>o.map(s=>({...s,title:n(s.title),section:n(s.section)}));return{bulkActionsHotKeys:O(()=>{let o=[];return e.value.length>0&&(o=[...Bo,...Lo,...Ho]),t(o)})}}const at=(n,e)=>n.map(t=>({...t,title:e(t.title),section:e(t.section)})),Zo=(n,e)=>[{label:n("CONVERSATION.PRIORITY.OPTIONS.NONE"),key:null,icon:eo},{label:n("CONVERSATION.PRIORITY.OPTIONS.URGENT"),key:"urgent",icon:Xi},{label:n("CONVERSATION.PRIORITY.OPTIONS.HIGH"),key:"high",icon:Ji},{label:n("CONVERSATION.PRIORITY.OPTIONS.MEDIUM"),key:"medium",icon:qi},{label:n("CONVERSATION.PRIORITY.OPTIONS.LOW"),key:"low",icon:Qi}].filter(t=>t.key!==e),Vo=(n,e)=>e===ti.REPLY?[{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.REPLY_SUGGESTION"),key:"reply_suggestion",icon:fe}]:[{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.SUMMARIZE"),key:"summarize",icon:to}],Uo=n=>[{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.CONFIDENT"),key:"confident",icon:fe},{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.FIX_SPELLING_GRAMMAR"),key:"fix_spelling_grammar",icon:oo},{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.PROFESSIONAL"),key:"professional",icon:no},{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.CASUAL"),key:"casual",icon:io},{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.MAKE_FRIENDLY"),key:"friendly",icon:fe},{label:n("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.STRAIGHTFORWARD"),key:"straightforward",icon:fe}];function Go(){const{t:n}=oe(),e=vt(),t=gt(),{activeLabels:i,inactiveLabels:o,addLabelToConversation:s,removeLabelFromConversation:a}=Gn(),{captainTasksEnabled:r}=Kn(),l=G("getSelectedChat"),c=G("draftMessages/getReplyEditorMode"),h=G("getContextMenuChatId"),d=G("teams/getTeams"),u=G("draftMessages/get"),p=O(()=>{var g;return(g=l.value)==null?void 0:g.id}),v=O(()=>`draft-${p.value}-${c.value}`),A=O(()=>u.value(v.value)),$=O(()=>{var g,f;return!!((f=(g=l.value)==null?void 0:g.meta)!=null&&f.team)}),W=O(()=>$.value?[{id:0,name:n("TEAMS_SETTINGS.LIST.NONE")},...d.value]:d.value),V=g=>{e.dispatch("assignPriority",{conversationId:l.value.id,priority:g.priority.key})},Se=g=>{e.dispatch("assignTeam",{conversationId:l.value.id,teamId:g.teamInfo.id})},U=O(()=>{var k,b,j;const g=((k=l.value)==null?void 0:k.status)===z.STATUS_TYPE.OPEN,f=((b=l.value)==null?void 0:b.status)===z.STATUS_TYPE.SNOOZED,_=((j=l.value)==null?void 0:j.status)===z.STATUS_TYPE.RESOLVED;let w=[];return g?w=[...Ro,...Xt]:(_||f)&&(w=$o),at(w,n)}),B=O(()=>{var g;return Zo(n,(g=l.value)==null?void 0:g.priority)}),Le=O(()=>{const g=B.value.map(f=>({id:`priority-${f.key}`,title:f.label,parent:"assign_priority",section:n("COMMAND_BAR.SECTIONS.CHANGE_PRIORITY"),priority:f,icon:f.icon,handler:V}));return[{id:"assign_priority",title:n("COMMAND_BAR.COMMANDS.ASSIGN_PRIORITY"),section:n("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:Wi,children:g.map(f=>f.id)},...g]}),He=O(()=>{const g=W.value.map(f=>({id:`team-${f.id}`,title:f.name,parent:"assign_a_team",section:n("COMMAND_BAR.SECTIONS.CHANGE_TEAM"),teamInfo:f,icon:Vt,handler:Se}));return[{id:"assign_a_team",title:n("COMMAND_BAR.COMMANDS.ASSIGN_A_TEAM"),section:n("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:Vt,children:g.map(f=>f.id)},...g]}),de=O(()=>[...o.value.map(f=>({id:f.title,title:`#${f.title}`,parent:"add_a_label_to_the_conversation",section:n("COMMAND_BAR.SECTIONS.ADD_LABEL"),icon:Pt,handler:_=>s({title:_.id})})),{id:"add_a_label_to_the_conversation",title:n("COMMAND_BAR.COMMANDS.ADD_LABELS_TO_CONVERSATION"),section:n("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:Pt,children:o.value.map(f=>f.title)}]),we=O(()=>[...i.value.map(f=>({id:f.title,title:`#${f.title}`,parent:"remove_a_label_to_the_conversation",section:n("COMMAND_BAR.SECTIONS.REMOVE_LABEL"),icon:Zt,handler:_=>a(_.id)})),{id:"remove_a_label_to_the_conversation",title:n("COMMAND_BAR.COMMANDS.REMOVE_LABEL_FROM_CONVERSATION"),section:n("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:Zt,children:i.value.map(f=>f.title)}]),Pe=O(()=>i.value.length?[...de.value,...we.value]:de.value),Ze=O(()=>at([l.value.muted?ko:jo,xo],n)),Ve=O(()=>{const f=(A.value?Uo(n):Vo(n,c.value)).map(_=>({id:`ai-assist-${_.key}`,title:_.label,parent:"ai_assist",section:n("COMMAND_BAR.SECTIONS.AI_ASSIST"),priority:_,icon:_.icon,handler:()=>H.emit(zn,_.key)}));return[{id:"ai_assist",title:n("COMMAND_BAR.COMMANDS.AI_ASSIST"),section:n("COMMAND_BAR.SECTIONS.AI_ASSIST"),icon:fe,children:f.map(_=>_.id)},...f]}),Ue=O(()=>rt(t.name)||ft(t.name)),Ee=O(()=>rt(t.name,!0,!1)&&h.value),Ge=O(()=>{const g=[...U.value,...Ze.value,...He.value,...Pe.value,...Le.value];return r.value?[...g,...Ve.value]:g});return{conversationHotKeys:O(()=>Ee.value?at(Xt,n):Ue.value?Ge.value:[])}}function Ko(){const{t:n}=oe(),e=vt(),t=gt(),{orderedMacros:i}=Fn(),{execute:o,submitPendingAttributes:s,dismissPendingAttributes:a}=Yn(),{isFeatureFlagEnabled:r}=Qt(),l=G("getSelectedChat"),c=Q(null),h=O(()=>r(ni.MACROS)&&(rt(t.name)||ft(t.name)));return Jt(h,u=>{u&&!i.value.length&&e.dispatch("macros/get")},{immediate:!0}),{macroHotKeys:O(()=>{if(!h.value||!i.value.length)return[];const u=i.value.map(p=>({id:`macro-${p.id}`,title:p.name,parent:"execute_a_macro",section:n("COMMAND_BAR.SECTIONS.EXECUTE_MACRO"),icon:_t,handler:()=>{c.value=o(p,l.value.id)}}));return[{id:"execute_a_macro",title:n("COMMAND_BAR.COMMANDS.EXECUTE_A_MACRO"),section:n("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:_t,children:u.map(p=>p.id)},...u]}),pendingAttributes:c,submitPendingAttributes:s,dismissPendingAttributes:a}}const zo=["placeholder"],Fo="dynamic_snooze_",Ts={__name:"commandbar",props:{isPaywalled:{type:Boolean,default:!1}},setup(n){const e=n,t=vt(),{t:i,tm:o}=oe(),{resolvedLocale:s}=Wn(),a=Q(null),r=Q(null),l=Q(null),{goToAppearanceHotKeys:c}=Eo(),{inboxHotKeys:h}=To(),{goToCommandHotKeys:d}=bo(En(e,"isPaywalled")),{bulkActionsHotKeys:u}=Po(),{conversationHotKeys:p}=Go(),{macroHotKeys:v,pendingAttributes:A,submitPendingAttributes:$,dismissPendingAttributes:W}=Ko();Jt(A,_=>{var w;_&&((w=r.value)==null||w.open(_.missing,_.customAttributes))});const V=["snooze_conversation","snooze_notification","bulk_action_snooze_conversation"],Se=z.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME,U=Q([]),B=Q(null),Le=O(()=>V.includes(B.value)?i("COMMAND_BAR.SNOOZE_PLACEHOLDER"):i("COMMAND_BAR.SEARCH_PLACEHOLDER")),He=new Set(Object.values(z.SNOOZE_OPTIONS)),de=O(()=>{if(e.isPaywalled)return[...c.value,...d.value];const _=[...U.value,...h.value,...d.value,...c.value,...u.value,...p.value,...v.value];return U.value.length?_.filter(w=>!He.has(w.id)||!V.includes(w.parent)):_}),we=()=>{a.value.data=de.value},Pe={snooze_conversation:en,snooze_notification:qt,bulk_action_snooze_conversation:tn},Ze={snooze_conversation:"COMMAND_BAR.SECTIONS.SNOOZE_CONVERSATION",snooze_notification:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",bulk_action_snooze_conversation:"COMMAND_BAR.SECTIONS.BULK_ACTIONS"},Ve=O(()=>{const _=o("SNOOZE_PARSER");return!_||typeof _!="object"?{}:JSON.parse(JSON.stringify(_))}),Ue=(_,w)=>{const k=Jn(_,new Date,{translations:Ve.value,locale:s.value});if(!k.length)return[];const b=Pe[w],j=i(Ze[w]);return k.map((P,wn)=>({id:`${Fo}${wn}`,title:P.label!==P.formattedDate?`${P.label} - ${P.formattedDate}`:P.formattedDate,parent:w,section:j,icon:Be,keywords:_,handler:()=>{H.emit(b,P.resolve()),Ct(oi.NLP_SNOOZE_APPLIED,{label:P.label})}}))},Ee=()=>{B.value=null,U.value=[]},Ge=_=>{if(!_||typeof _.open!="function"||typeof _.close!="function")return;const w=_.open.bind(_),k=_.close.bind(_);_.open=(...b)=>{const[j={}]=b;return B.value=j.parent||null,U.value=[],w(...b)},_.close=(...b)=>(Ee(),k(...b))},mt=_=>{const{detail:{action:{title:w=null,section:k=null,id:b=null,children:j=null}={}}={}}=_;l.value=b===Se?b:null,Array.isArray(j)&&j.length&&(B.value=b),Ct(ii.COMMAND_BAR,{section:k,action:w}),we()},g=_=>{const{detail:{search:w="",actions:k=[]}={}}=_,b=w.trim();if(k.length>0){const j=[...new Set(k.map(P=>P.parent).filter(Boolean))];j.length===1?B.value=j[0]:B.value=null}if(!b||!V.includes(B.value||"")){U.value=[];return}U.value=Ue(b,B.value)},f=()=>{l.value!==Se&&t.dispatch("setContextMenuChatId",null),Ee()};return yn(()=>{a.value&&(a.value.data=de.value)}),Tn(()=>{we(),Ge(a.value)}),(_,w)=>(In(),bn(xn,null,[Rn("ninja-keys",{ref_key:"ninjakeys",ref:a,noAutoLoadMdIcons:"",hideBreadcrumbs:"",placeholder:Le.value,onChange:g,onSelected:mt,onClosed:f},null,40,zo),$n(Xn,{ref_key:"resolveAttributesModalRef",ref:r,onSubmit:Nt($),onClose:Nt(W)},null,8,["onSubmit","onClose"])],64))}};export{Ts as default};
//# sourceMappingURL=commandbar-DBvc3ylr.js.map
