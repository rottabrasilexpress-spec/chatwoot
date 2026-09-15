import{c as m,r as J,w as Pt,af as _i,a9 as vi,H as fi,o as gi,e as mi,g as Ai,k as Oi,B as ut,F as Ci}from"./_plugin-vue_export-helper-HocTlhOb.js";import{W as wi,u as ae,e as le,b as pe,c as rt}from"./useBranding-Cy3MIthI.js";import{a as pt}from"./index-CELBFul7.js";import{P as Ni,Q as at,R as Zt,S as Ut,T as Mi,U as yi,V as Si,W as Ei,X as bi,Y as Ti,Z as $i,$ as Gt,a0 as Ii,a1 as xi,a2 as Ri,a3 as ki,a4 as ji}from"./dashboard-t7cB-ix7.js";import{L as Di,u as lt,w as qe,a as Bi}from"./Validators-DThjOm4-.js";import{L as Hi,N as Li,F as Pi,bT as Zi,bU as Ui}from"./DashboardIcon-BmbHuUsE.js";import"./utils.esm-DY_uR2pP.js";import"./_commonjsHelpers-gnU0ypJ3.js";import"./index-CNbQRP5E.js";import"./index-DPTuQ6cd.js";import"./index-DN3rM4CW.js";import"./typing-C39iqh-S.js";import"./index-CDRp_7W2.js";import"./vue-dompurify-html-DrFQMDmR.js";import"./useKeyboardNavigableList-B-rcp2-w.js";import"./helper-BVTgYTlr.js";import"./index-BGNljRnU.js";import"./Icon-BuG2LY7U.js";import"./module-CdxxqO8d.js";import"./chatwoot-viz-CAuNW29n.js";import"./index-DfsDTqrj.js";import"./constants-lVAyZKq6.js";import"./IframeLoader-DciPSguK.js";import"./HTMLSanitizer-cciupgGC.js";import"./js.cookie-Cz0CWeBA.js";/**
 * @license
 * Copyright 2019 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const ye=window,ct=ye.ShadowRoot&&(ye.ShadyCSS===void 0||ye.ShadyCSS.nativeShadow)&&"adoptedStyleSheets"in Document.prototype&&"replace"in CSSStyleSheet.prototype,ht=Symbol(),_t=new WeakMap;let Vt=class{constructor(e,t,n){if(this._$cssResult$=!0,n!==ht)throw Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");this.cssText=e,this.t=t}get styleSheet(){let e=this.o;const t=this.t;if(ct&&e===void 0){const n=t!==void 0&&t.length===1;n&&(e=_t.get(t)),e===void 0&&((this.o=e=new CSSStyleSheet).replaceSync(this.cssText),n&&_t.set(t,e))}return e}toString(){return this.cssText}};const Gi=i=>new Vt(typeof i=="string"?i:i+"",void 0,ht),Te=(i,...e)=>{const t=i.length===1?i[0]:e.reduce(((n,o,s)=>n+(r=>{if(r._$cssResult$===!0)return r.cssText;if(typeof r=="number")return r;throw Error("Value passed to 'css' function must be a 'css' function result: "+r+". Use 'unsafeCSS' to pass non-literal values, but take care to ensure page security.")})(o)+i[s+1]),i[0]);return new Vt(t,i,ht)},Vi=(i,e)=>{ct?i.adoptedStyleSheets=e.map((t=>t instanceof CSSStyleSheet?t:t.styleSheet)):e.forEach((t=>{const n=document.createElement("style"),o=ye.litNonce;o!==void 0&&n.setAttribute("nonce",o),n.textContent=t.cssText,i.appendChild(n)}))},vt=ct?i=>i:i=>i instanceof CSSStyleSheet?(e=>{let t="";for(const n of e.cssRules)t+=n.cssText;return Gi(t)})(i):i;/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Be;const Se=window,ft=Se.trustedTypes,Ki=ft?ft.emptyScript:"",gt=Se.reactiveElementPolyfillSupport,Qe={toAttribute(i,e){switch(e){case Boolean:i=i?Ki:null;break;case Object:case Array:i=i==null?i:JSON.stringify(i)}return i},fromAttribute(i,e){let t=i;switch(e){case Boolean:t=i!==null;break;case Number:t=i===null?null:Number(i);break;case Object:case Array:try{t=JSON.parse(i)}catch{t=null}}return t}},Kt=(i,e)=>e!==i&&(e==e||i==i),He={attribute:!0,type:String,converter:Qe,reflect:!1,hasChanged:Kt},et="finalized";let ne=class extends HTMLElement{constructor(){super(),this._$Ei=new Map,this.isUpdatePending=!1,this.hasUpdated=!1,this._$El=null,this._$Eu()}static addInitializer(e){var t;this.finalize(),((t=this.h)!==null&&t!==void 0?t:this.h=[]).push(e)}static get observedAttributes(){this.finalize();const e=[];return this.elementProperties.forEach(((t,n)=>{const o=this._$Ep(n,t);o!==void 0&&(this._$Ev.set(o,n),e.push(o))})),e}static createProperty(e,t=He){if(t.state&&(t.attribute=!1),this.finalize(),this.elementProperties.set(e,t),!t.noAccessor&&!this.prototype.hasOwnProperty(e)){const n=typeof e=="symbol"?Symbol():"__"+e,o=this.getPropertyDescriptor(e,n,t);o!==void 0&&Object.defineProperty(this.prototype,e,o)}}static getPropertyDescriptor(e,t,n){return{get(){return this[t]},set(o){const s=this[e];this[t]=o,this.requestUpdate(e,s,n)},configurable:!0,enumerable:!0}}static getPropertyOptions(e){return this.elementProperties.get(e)||He}static finalize(){if(this.hasOwnProperty(et))return!1;this[et]=!0;const e=Object.getPrototypeOf(this);if(e.finalize(),e.h!==void 0&&(this.h=[...e.h]),this.elementProperties=new Map(e.elementProperties),this._$Ev=new Map,this.hasOwnProperty("properties")){const t=this.properties,n=[...Object.getOwnPropertyNames(t),...Object.getOwnPropertySymbols(t)];for(const o of n)this.createProperty(o,t[o])}return this.elementStyles=this.finalizeStyles(this.styles),!0}static finalizeStyles(e){const t=[];if(Array.isArray(e)){const n=new Set(e.flat(1/0).reverse());for(const o of n)t.unshift(vt(o))}else e!==void 0&&t.push(vt(e));return t}static _$Ep(e,t){const n=t.attribute;return n===!1?void 0:typeof n=="string"?n:typeof e=="string"?e.toLowerCase():void 0}_$Eu(){var e;this._$E_=new Promise((t=>this.enableUpdating=t)),this._$AL=new Map,this._$Eg(),this.requestUpdate(),(e=this.constructor.h)===null||e===void 0||e.forEach((t=>t(this)))}addController(e){var t,n;((t=this._$ES)!==null&&t!==void 0?t:this._$ES=[]).push(e),this.renderRoot!==void 0&&this.isConnected&&((n=e.hostConnected)===null||n===void 0||n.call(e))}removeController(e){var t;(t=this._$ES)===null||t===void 0||t.splice(this._$ES.indexOf(e)>>>0,1)}_$Eg(){this.constructor.elementProperties.forEach(((e,t)=>{this.hasOwnProperty(t)&&(this._$Ei.set(t,this[t]),delete this[t])}))}createRenderRoot(){var e;const t=(e=this.shadowRoot)!==null&&e!==void 0?e:this.attachShadow(this.constructor.shadowRootOptions);return Vi(t,this.constructor.elementStyles),t}connectedCallback(){var e;this.renderRoot===void 0&&(this.renderRoot=this.createRenderRoot()),this.enableUpdating(!0),(e=this._$ES)===null||e===void 0||e.forEach((t=>{var n;return(n=t.hostConnected)===null||n===void 0?void 0:n.call(t)}))}enableUpdating(e){}disconnectedCallback(){var e;(e=this._$ES)===null||e===void 0||e.forEach((t=>{var n;return(n=t.hostDisconnected)===null||n===void 0?void 0:n.call(t)}))}attributeChangedCallback(e,t,n){this._$AK(e,n)}_$EO(e,t,n=He){var o;const s=this.constructor._$Ep(e,n);if(s!==void 0&&n.reflect===!0){const r=(((o=n.converter)===null||o===void 0?void 0:o.toAttribute)!==void 0?n.converter:Qe).toAttribute(t,n.type);this._$El=e,r==null?this.removeAttribute(s):this.setAttribute(s,r),this._$El=null}}_$AK(e,t){var n;const o=this.constructor,s=o._$Ev.get(e);if(s!==void 0&&this._$El!==s){const r=o.getPropertyOptions(s),a=typeof r.converter=="function"?{fromAttribute:r.converter}:((n=r.converter)===null||n===void 0?void 0:n.fromAttribute)!==void 0?r.converter:Qe;this._$El=s,this[s]=a.fromAttribute(t,r.type),this._$El=null}}requestUpdate(e,t,n){let o=!0;e!==void 0&&(((n=n||this.constructor.getPropertyOptions(e)).hasChanged||Kt)(this[e],t)?(this._$AL.has(e)||this._$AL.set(e,t),n.reflect===!0&&this._$El!==e&&(this._$EC===void 0&&(this._$EC=new Map),this._$EC.set(e,n))):o=!1),!this.isUpdatePending&&o&&(this._$E_=this._$Ej())}async _$Ej(){this.isUpdatePending=!0;try{await this._$E_}catch(t){Promise.reject(t)}const e=this.scheduleUpdate();return e!=null&&await e,!this.isUpdatePending}scheduleUpdate(){return this.performUpdate()}performUpdate(){var e;if(!this.isUpdatePending)return;this.hasUpdated,this._$Ei&&(this._$Ei.forEach(((o,s)=>this[s]=o)),this._$Ei=void 0);let t=!1;const n=this._$AL;try{t=this.shouldUpdate(n),t?(this.willUpdate(n),(e=this._$ES)===null||e===void 0||e.forEach((o=>{var s;return(s=o.hostUpdate)===null||s===void 0?void 0:s.call(o)})),this.update(n)):this._$Ek()}catch(o){throw t=!1,this._$Ek(),o}t&&this._$AE(n)}willUpdate(e){}_$AE(e){var t;(t=this._$ES)===null||t===void 0||t.forEach((n=>{var o;return(o=n.hostUpdated)===null||o===void 0?void 0:o.call(n)})),this.hasUpdated||(this.hasUpdated=!0,this.firstUpdated(e)),this.updated(e)}_$Ek(){this._$AL=new Map,this.isUpdatePending=!1}get updateComplete(){return this.getUpdateComplete()}getUpdateComplete(){return this._$E_}shouldUpdate(e){return!0}update(e){this._$EC!==void 0&&(this._$EC.forEach(((t,n)=>this._$EO(n,this[n],t))),this._$EC=void 0),this._$Ek()}updated(e){}firstUpdated(e){}};ne[et]=!0,ne.elementProperties=new Map,ne.elementStyles=[],ne.shadowRootOptions={mode:"open"},gt==null||gt({ReactiveElement:ne}),((Be=Se.reactiveElementVersions)!==null&&Be!==void 0?Be:Se.reactiveElementVersions=[]).push("1.6.3");/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Le;const Ee=window,oe=Ee.trustedTypes,mt=oe?oe.createPolicy("lit-html",{createHTML:i=>i}):void 0,tt="$lit$",K=`lit$${(Math.random()+"").slice(9)}$`,zt="?"+K,zi=`<${zt}>`,Q=document,fe=()=>Q.createComment(""),ge=i=>i===null||typeof i!="object"&&typeof i!="function",Ft=Array.isArray,Fi=i=>Ft(i)||typeof(i==null?void 0:i[Symbol.iterator])=="function",Pe=`[ 	
\f\r]`,he=/<(?:(!--|\/[^a-zA-Z])|(\/?[a-zA-Z][^>\s]*)|(\/?$))/g,At=/-->/g,Ot=/>/g,Y=RegExp(`>|${Pe}(?:([^\\s"'>=/]+)(${Pe}*=${Pe}*(?:[^ 	
\f\r"'\`<>=]|("|')|))|$)`,"g"),Ct=/'/g,wt=/"/g,Yt=/^(?:script|style|textarea|title)$/i,Yi=i=>(e,...t)=>({_$litType$:i,strings:e,values:t}),b=Yi(1),k=Symbol.for("lit-noChange"),A=Symbol.for("lit-nothing"),Nt=new WeakMap,q=Q.createTreeWalker(Q,129,null,!1);function Wt(i,e){if(!Array.isArray(i)||!i.hasOwnProperty("raw"))throw Error("invalid template strings array");return mt!==void 0?mt.createHTML(e):e}const Wi=(i,e)=>{const t=i.length-1,n=[];let o,s=e===2?"<svg>":"",r=he;for(let a=0;a<t;a++){const l=i[a];let c,h,d=-1,u=0;for(;u<l.length&&(r.lastIndex=u,h=r.exec(l),h!==null);)u=r.lastIndex,r===he?h[1]==="!--"?r=At:h[1]!==void 0?r=Ot:h[2]!==void 0?(Yt.test(h[2])&&(o=RegExp("</"+h[2],"g")),r=Y):h[3]!==void 0&&(r=Y):r===Y?h[0]===">"?(r=o??he,d=-1):h[1]===void 0?d=-2:(d=r.lastIndex-h[2].length,c=h[1],r=h[3]===void 0?Y:h[3]==='"'?wt:Ct):r===wt||r===Ct?r=Y:r===At||r===Ot?r=he:(r=Y,o=void 0);const p=r===Y&&i[a+1].startsWith("/>")?" ":"";s+=r===he?l+zi:d>=0?(n.push(c),l.slice(0,d)+tt+l.slice(d)+K+p):l+K+(d===-2?(n.push(void 0),a):p)}return[Wt(i,s+(i[t]||"<?>")+(e===2?"</svg>":"")),n]};class me{constructor({strings:e,_$litType$:t},n){let o;this.parts=[];let s=0,r=0;const a=e.length-1,l=this.parts,[c,h]=Wi(e,t);if(this.el=me.createElement(c,n),q.currentNode=this.el.content,t===2){const d=this.el.content,u=d.firstChild;u.remove(),d.append(...u.childNodes)}for(;(o=q.nextNode())!==null&&l.length<a;){if(o.nodeType===1){if(o.hasAttributes()){const d=[];for(const u of o.getAttributeNames())if(u.endsWith(tt)||u.startsWith(K)){const p=h[r++];if(d.push(u),p!==void 0){const _=o.getAttribute(p.toLowerCase()+tt).split(K),f=/([.?@])?(.*)/.exec(p);l.push({type:1,index:s,name:f[2],strings:_,ctor:f[1]==="."?Ji:f[1]==="?"?Qi:f[1]==="@"?en:$e})}else l.push({type:6,index:s})}for(const u of d)o.removeAttribute(u)}if(Yt.test(o.tagName)){const d=o.textContent.split(K),u=d.length-1;if(u>0){o.textContent=oe?oe.emptyScript:"";for(let p=0;p<u;p++)o.append(d[p],fe()),q.nextNode(),l.push({type:2,index:++s});o.append(d[u],fe())}}}else if(o.nodeType===8)if(o.data===zt)l.push({type:2,index:s});else{let d=-1;for(;(d=o.data.indexOf(K,d+1))!==-1;)l.push({type:7,index:s}),d+=K.length-1}s++}}static createElement(e,t){const n=Q.createElement("template");return n.innerHTML=e,n}}function se(i,e,t=i,n){var o,s,r,a;if(e===k)return e;let l=n!==void 0?(o=t._$Co)===null||o===void 0?void 0:o[n]:t._$Cl;const c=ge(e)?void 0:e._$litDirective$;return(l==null?void 0:l.constructor)!==c&&((s=l==null?void 0:l._$AO)===null||s===void 0||s.call(l,!1),c===void 0?l=void 0:(l=new c(i),l._$AT(i,t,n)),n!==void 0?((r=(a=t)._$Co)!==null&&r!==void 0?r:a._$Co=[])[n]=l:t._$Cl=l),l!==void 0&&(e=se(i,l._$AS(i,e.values),l,n)),e}class Xi{constructor(e,t){this._$AV=[],this._$AN=void 0,this._$AD=e,this._$AM=t}get parentNode(){return this._$AM.parentNode}get _$AU(){return this._$AM._$AU}u(e){var t;const{el:{content:n},parts:o}=this._$AD,s=((t=e==null?void 0:e.creationScope)!==null&&t!==void 0?t:Q).importNode(n,!0);q.currentNode=s;let r=q.nextNode(),a=0,l=0,c=o[0];for(;c!==void 0;){if(a===c.index){let h;c.type===2?h=new ce(r,r.nextSibling,this,e):c.type===1?h=new c.ctor(r,c.name,c.strings,this,e):c.type===6&&(h=new tn(r,this,e)),this._$AV.push(h),c=o[++l]}a!==(c==null?void 0:c.index)&&(r=q.nextNode(),a++)}return q.currentNode=Q,s}v(e){let t=0;for(const n of this._$AV)n!==void 0&&(n.strings!==void 0?(n._$AI(e,n,t),t+=n.strings.length-2):n._$AI(e[t])),t++}}class ce{constructor(e,t,n,o){var s;this.type=2,this._$AH=A,this._$AN=void 0,this._$AA=e,this._$AB=t,this._$AM=n,this.options=o,this._$Cp=(s=o==null?void 0:o.isConnected)===null||s===void 0||s}get _$AU(){var e,t;return(t=(e=this._$AM)===null||e===void 0?void 0:e._$AU)!==null&&t!==void 0?t:this._$Cp}get parentNode(){let e=this._$AA.parentNode;const t=this._$AM;return t!==void 0&&(e==null?void 0:e.nodeType)===11&&(e=t.parentNode),e}get startNode(){return this._$AA}get endNode(){return this._$AB}_$AI(e,t=this){e=se(this,e,t),ge(e)?e===A||e==null||e===""?(this._$AH!==A&&this._$AR(),this._$AH=A):e!==this._$AH&&e!==k&&this._(e):e._$litType$!==void 0?this.g(e):e.nodeType!==void 0?this.$(e):Fi(e)?this.T(e):this._(e)}k(e){return this._$AA.parentNode.insertBefore(e,this._$AB)}$(e){this._$AH!==e&&(this._$AR(),this._$AH=this.k(e))}_(e){this._$AH!==A&&ge(this._$AH)?this._$AA.nextSibling.data=e:this.$(Q.createTextNode(e)),this._$AH=e}g(e){var t;const{values:n,_$litType$:o}=e,s=typeof o=="number"?this._$AC(e):(o.el===void 0&&(o.el=me.createElement(Wt(o.h,o.h[0]),this.options)),o);if(((t=this._$AH)===null||t===void 0?void 0:t._$AD)===s)this._$AH.v(n);else{const r=new Xi(s,this),a=r.u(this.options);r.v(n),this.$(a),this._$AH=r}}_$AC(e){let t=Nt.get(e.strings);return t===void 0&&Nt.set(e.strings,t=new me(e)),t}T(e){Ft(this._$AH)||(this._$AH=[],this._$AR());const t=this._$AH;let n,o=0;for(const s of e)o===t.length?t.push(n=new ce(this.k(fe()),this.k(fe()),this,this.options)):n=t[o],n._$AI(s),o++;o<t.length&&(this._$AR(n&&n._$AB.nextSibling,o),t.length=o)}_$AR(e=this._$AA.nextSibling,t){var n;for((n=this._$AP)===null||n===void 0||n.call(this,!1,!0,t);e&&e!==this._$AB;){const o=e.nextSibling;e.remove(),e=o}}setConnected(e){var t;this._$AM===void 0&&(this._$Cp=e,(t=this._$AP)===null||t===void 0||t.call(this,e))}}let $e=class{constructor(e,t,n,o,s){this.type=1,this._$AH=A,this._$AN=void 0,this.element=e,this.name=t,this._$AM=o,this.options=s,n.length>2||n[0]!==""||n[1]!==""?(this._$AH=Array(n.length-1).fill(new String),this.strings=n):this._$AH=A}get tagName(){return this.element.tagName}get _$AU(){return this._$AM._$AU}_$AI(e,t=this,n,o){const s=this.strings;let r=!1;if(s===void 0)e=se(this,e,t,0),r=!ge(e)||e!==this._$AH&&e!==k,r&&(this._$AH=e);else{const a=e;let l,c;for(e=s[0],l=0;l<s.length-1;l++)c=se(this,a[n+l],t,l),c===k&&(c=this._$AH[l]),r||(r=!ge(c)||c!==this._$AH[l]),c===A?e=A:e!==A&&(e+=(c??"")+s[l+1]),this._$AH[l]=c}r&&!o&&this.j(e)}j(e){e===A?this.element.removeAttribute(this.name):this.element.setAttribute(this.name,e??"")}};class Ji extends $e{constructor(){super(...arguments),this.type=3}j(e){this.element[this.name]=e===A?void 0:e}}const qi=oe?oe.emptyScript:"";class Qi extends $e{constructor(){super(...arguments),this.type=4}j(e){e&&e!==A?this.element.setAttribute(this.name,qi):this.element.removeAttribute(this.name)}}class en extends $e{constructor(e,t,n,o,s){super(e,t,n,o,s),this.type=5}_$AI(e,t=this){var n;if((e=(n=se(this,e,t,0))!==null&&n!==void 0?n:A)===k)return;const o=this._$AH,s=e===A&&o!==A||e.capture!==o.capture||e.once!==o.once||e.passive!==o.passive,r=e!==A&&(o===A||s);s&&this.element.removeEventListener(this.name,this,o),r&&this.element.addEventListener(this.name,this,e),this._$AH=e}handleEvent(e){var t,n;typeof this._$AH=="function"?this._$AH.call((n=(t=this.options)===null||t===void 0?void 0:t.host)!==null&&n!==void 0?n:this.element,e):this._$AH.handleEvent(e)}}class tn{constructor(e,t,n){this.element=e,this.type=6,this._$AN=void 0,this._$AM=t,this.options=n}get _$AU(){return this._$AM._$AU}_$AI(e){se(this,e)}}const nn={I:ce},Mt=Ee.litHtmlPolyfillSupport;Mt==null||Mt(me,ce),((Le=Ee.litHtmlVersions)!==null&&Le!==void 0?Le:Ee.litHtmlVersions=[]).push("2.8.0");const on=(i,e,t)=>{var n,o;const s=(n=t==null?void 0:t.renderBefore)!==null&&n!==void 0?n:e;let r=s._$litPart$;if(r===void 0){const a=(o=t==null?void 0:t.renderBefore)!==null&&o!==void 0?o:null;s._$litPart$=r=new ce(e.insertBefore(fe(),a),a,void 0,t??{})}return r._$AI(i),r};/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Ze,Ue;let z=class extends ne{constructor(){super(...arguments),this.renderOptions={host:this},this._$Do=void 0}createRenderRoot(){var e,t;const n=super.createRenderRoot();return(e=(t=this.renderOptions).renderBefore)!==null&&e!==void 0||(t.renderBefore=n.firstChild),n}update(e){const t=this.render();this.hasUpdated||(this.renderOptions.isConnected=this.isConnected),super.update(e),this._$Do=on(t,this.renderRoot,this.renderOptions)}connectedCallback(){var e;super.connectedCallback(),(e=this._$Do)===null||e===void 0||e.setConnected(!0)}disconnectedCallback(){var e;super.disconnectedCallback(),(e=this._$Do)===null||e===void 0||e.setConnected(!1)}render(){return k}};z.finalized=!0,z._$litElement$=!0,(Ze=globalThis.litElementHydrateSupport)===null||Ze===void 0||Ze.call(globalThis,{LitElement:z});const yt=globalThis.litElementPolyfillSupport;yt==null||yt({LitElement:z});((Ue=globalThis.litElementVersions)!==null&&Ue!==void 0?Ue:globalThis.litElementVersions=[]).push("3.3.3");/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Ie=i=>e=>typeof e=="function"?((t,n)=>(customElements.define(t,n),n))(i,e):((t,n)=>{const{kind:o,elements:s}=n;return{kind:o,elements:s,finisher(r){customElements.define(t,r)}}})(i,e);/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const sn=(i,e)=>e.kind==="method"&&e.descriptor&&!("value"in e.descriptor)?{...e,finisher(t){t.createProperty(e.key,i)}}:{kind:"field",key:Symbol(),placement:"own",descriptor:{},originalKey:e.key,initializer(){typeof e.initializer=="function"&&(this[e.key]=e.initializer.call(this))},finisher(t){t.createProperty(e.key,i)}},rn=(i,e,t)=>{e.constructor.createProperty(t,i)};function M(i){return(e,t)=>t!==void 0?rn(i,e,t):sn(i,e)}/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */function F(i){return M({...i,state:!0})}/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */var Ge;((Ge=window.HTMLSlotElement)===null||Ge===void 0?void 0:Ge.prototype.assignedElements)!=null;/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const B={ATTRIBUTE:1,CHILD:2,PROPERTY:3,BOOLEAN_ATTRIBUTE:4},Oe=i=>(...e)=>({_$litDirective$:i,values:e});class Ce{constructor(e){}get _$AU(){return this._$AM._$AU}_$AT(e,t,n){this._$Ct=e,this._$AM=t,this._$Ci=n}_$AS(e,t){return this.update(e,t)}update(e,t){return this.render(...t)}}/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const{I:an}=nn,Xt=i=>i.strings===void 0,St=()=>document.createComment(""),de=(i,e,t)=>{var n;const o=i._$AA.parentNode,s=e===void 0?i._$AB:e._$AA;if(t===void 0){const r=o.insertBefore(St(),s),a=o.insertBefore(St(),s);t=new an(r,a,i,i.options)}else{const r=t._$AB.nextSibling,a=t._$AM,l=a!==i;if(l){let c;(n=t._$AQ)===null||n===void 0||n.call(t,i),t._$AM=i,t._$AP!==void 0&&(c=i._$AU)!==a._$AU&&t._$AP(c)}if(r!==s||l){let c=t._$AA;for(;c!==r;){const h=c.nextSibling;o.insertBefore(c,s),c=h}}}return t},W=(i,e,t=i)=>(i._$AI(e,t),i),ln={},Jt=(i,e=ln)=>i._$AH=e,cn=i=>i._$AH,Ve=i=>{var e;(e=i._$AP)===null||e===void 0||e.call(i,!1,!0);let t=i._$AA;const n=i._$AB.nextSibling;for(;t!==n;){const o=t.nextSibling;t.remove(),t=o}};/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Et=(i,e,t)=>{const n=new Map;for(let o=e;o<=t;o++)n.set(i[o],o);return n},hn=Oe(class extends Ce{constructor(i){if(super(i),i.type!==B.CHILD)throw Error("repeat() can only be used in text expressions")}ct(i,e,t){let n;t===void 0?t=e:e!==void 0&&(n=e);const o=[],s=[];let r=0;for(const a of i)o[r]=n?n(a,r):r,s[r]=t(a,r),r++;return{values:s,keys:o}}render(i,e,t){return this.ct(i,e,t).values}update(i,[e,t,n]){var o;const s=cn(i),{values:r,keys:a}=this.ct(e,t,n);if(!Array.isArray(s))return this.ut=a,r;const l=(o=this.ut)!==null&&o!==void 0?o:this.ut=[],c=[];let h,d,u=0,p=s.length-1,_=0,f=r.length-1;for(;u<=p&&_<=f;)if(s[u]===null)u++;else if(s[p]===null)p--;else if(l[u]===a[_])c[_]=W(s[u],r[_]),u++,_++;else if(l[p]===a[f])c[f]=W(s[p],r[f]),p--,f--;else if(l[u]===a[f])c[f]=W(s[u],r[f]),de(i,c[f+1],s[u]),u++,f--;else if(l[p]===a[_])c[_]=W(s[p],r[_]),de(i,s[u],s[p]),p--,_++;else if(h===void 0&&(h=Et(a,_,f),d=Et(l,u,p)),h.has(l[u]))if(h.has(l[p])){const I=d.get(a[_]),U=I!==void 0?s[I]:null;if(U===null){const G=de(i,s[u]);W(G,r[_]),c[_]=G}else c[_]=W(U,r[_]),de(i,s[u],U),s[I]=null;_++}else Ve(s[p]),p--;else Ve(s[u]),u++;for(;_<=f;){const I=de(i,c[f+1]);W(I,r[_]),c[_++]=I}for(;u<=p;){const I=s[u++];I!==null&&Ve(I)}return this.ut=a,Jt(i,c),k}});/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const dn=Oe(class extends Ce{constructor(i){if(super(i),i.type!==B.PROPERTY&&i.type!==B.ATTRIBUTE&&i.type!==B.BOOLEAN_ATTRIBUTE)throw Error("The `live` directive is not allowed on child or event bindings");if(!Xt(i))throw Error("`live` bindings can only contain a single expression")}render(i){return i}update(i,[e]){if(e===k||e===A)return e;const t=i.element,n=i.name;if(i.type===B.PROPERTY){if(e===t[n])return k}else if(i.type===B.BOOLEAN_ATTRIBUTE){if(!!e===t.hasAttribute(n))return k}else if(i.type===B.ATTRIBUTE&&t.getAttribute(n)===e+"")return k;return Jt(i),e}});/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const _e=(i,e)=>{var t,n;const o=i._$AN;if(o===void 0)return!1;for(const s of o)(n=(t=s)._$AO)===null||n===void 0||n.call(t,e,!1),_e(s,e);return!0},be=i=>{let e,t;do{if((e=i._$AM)===void 0)break;t=e._$AN,t.delete(i),i=e}while((t==null?void 0:t.size)===0)},qt=i=>{for(let e;e=i._$AM;i=e){let t=e._$AN;if(t===void 0)e._$AN=t=new Set;else if(t.has(i))break;t.add(i),_n(e)}};function un(i){this._$AN!==void 0?(be(this),this._$AM=i,qt(this)):this._$AM=i}function pn(i,e=!1,t=0){const n=this._$AH,o=this._$AN;if(o!==void 0&&o.size!==0)if(e)if(Array.isArray(n))for(let s=t;s<n.length;s++)_e(n[s],!1),be(n[s]);else n!=null&&(_e(n,!1),be(n));else _e(this,i)}const _n=i=>{var e,t,n,o;i.type==B.CHILD&&((e=(n=i)._$AP)!==null&&e!==void 0||(n._$AP=pn),(t=(o=i)._$AQ)!==null&&t!==void 0||(o._$AQ=un))};class vn extends Ce{constructor(){super(...arguments),this._$AN=void 0}_$AT(e,t,n){super._$AT(e,t,n),qt(this),this.isConnected=e._$AU}_$AO(e,t=!0){var n,o;e!==this.isConnected&&(this.isConnected=e,e?(n=this.reconnected)===null||n===void 0||n.call(this):(o=this.disconnected)===null||o===void 0||o.call(this)),t&&(_e(this,e),be(this))}setValue(e){if(Xt(this._$Ct))this._$Ct._$AI(e,this);else{const t=[...this._$Ct._$AH];t[this._$Ci]=e,this._$Ct._$AI(t,this,0)}}disconnected(){}reconnected(){}}/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const Qt=()=>new fn;let fn=class{};const Ke=new WeakMap,ei=Oe(class extends vn{render(i){return A}update(i,[e]){var t;const n=e!==this.G;return n&&this.G!==void 0&&this.ot(void 0),(n||this.rt!==this.lt)&&(this.G=e,this.dt=(t=i.options)===null||t===void 0?void 0:t.host,this.ot(this.lt=i.element)),A}ot(i){var e;if(typeof this.G=="function"){const t=(e=this.dt)!==null&&e!==void 0?e:globalThis;let n=Ke.get(t);n===void 0&&(n=new WeakMap,Ke.set(t,n)),n.get(this.G)!==void 0&&this.G.call(this.dt,void 0),n.set(this.G,i),i!==void 0&&this.G.call(this.dt,i)}else this.G.value=i}get rt(){var i,e,t;return typeof this.G=="function"?(e=Ke.get((i=this.dt)!==null&&i!==void 0?i:globalThis))===null||e===void 0?void 0:e.get(this.G):(t=this.G)===null||t===void 0?void 0:t.value}disconnected(){this.rt===this.lt&&this.ot(void 0)}reconnected(){this.ot(this.lt)}});/**
 * @license
 * Copyright 2018 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */const it=Oe(class extends Ce{constructor(i){var e;if(super(i),i.type!==B.ATTRIBUTE||i.name!=="class"||((e=i.strings)===null||e===void 0?void 0:e.length)>2)throw Error("`classMap()` can only be used in the `class` attribute and must be the only part in the attribute.")}render(i){return" "+Object.keys(i).filter((e=>i[e])).join(" ")+" "}update(i,[e]){var t,n;if(this.it===void 0){this.it=new Set,i.strings!==void 0&&(this.nt=new Set(i.strings.join(" ").split(/\s/).filter((s=>s!==""))));for(const s in e)e[s]&&!(!((t=this.nt)===null||t===void 0)&&t.has(s))&&this.it.add(s);return this.render(e)}const o=i.element.classList;this.it.forEach((s=>{s in e||(o.remove(s),this.it.delete(s))}));for(const s in e){const r=!!e[s];r===this.it.has(s)||!((n=this.nt)===null||n===void 0)&&n.has(s)||(r?(o.add(s),this.it.add(s)):(o.remove(s),this.it.delete(s)))}return k}});/*!
 * hotkeys-js v3.8.7
 * A simple micro-library for defining and dispatching keyboard shortcuts. It has no dependencies.
 * 
 * Copyright (c) 2021 kenny wong <wowohoo@qq.com>
 * http://jaywcjlove.github.io/hotkeys
 * 
 * Licensed under the MIT license.
 */var ze=typeof navigator<"u"?navigator.userAgent.toLowerCase().indexOf("firefox")>0:!1;function Fe(i,e,t){i.addEventListener?i.addEventListener(e,t,!1):i.attachEvent&&i.attachEvent("on".concat(e),function(){t(window.event)})}function ti(i,e){for(var t=e.slice(0,e.length-1),n=0;n<t.length;n++)t[n]=i[t[n].toLowerCase()];return t}function ii(i){typeof i!="string"&&(i=""),i=i.replace(/\s/g,"");for(var e=i.split(","),t=e.lastIndexOf("");t>=0;)e[t-1]+=",",e.splice(t,1),t=e.lastIndexOf("");return e}function gn(i,e){for(var t=i.length>=e.length?i:e,n=i.length>=e.length?e:i,o=!0,s=0;s<t.length;s++)n.indexOf(t[s])===-1&&(o=!1);return o}var ni={backspace:8,tab:9,clear:12,enter:13,return:13,esc:27,escape:27,space:32,left:37,up:38,right:39,down:40,del:46,delete:46,ins:45,insert:45,home:36,end:35,pageup:33,pagedown:34,capslock:20,num_0:96,num_1:97,num_2:98,num_3:99,num_4:100,num_5:101,num_6:102,num_7:103,num_8:104,num_9:105,num_multiply:106,num_add:107,num_enter:108,num_subtract:109,num_decimal:110,num_divide:111,"⇪":20,",":188,".":190,"/":191,"`":192,"-":ze?173:189,"=":ze?61:187,";":ze?59:186,"'":222,"[":219,"]":221,"\\":220},ee={"⇧":16,shift:16,"⌥":18,alt:18,option:18,"⌃":17,ctrl:17,control:17,"⌘":91,cmd:91,command:91},bt={16:"shiftKey",18:"altKey",17:"ctrlKey",91:"metaKey",shiftKey:16,ctrlKey:17,altKey:18,metaKey:91},E={16:!1,18:!1,17:!1,91:!1},S={};for(var Me=1;Me<20;Me++)ni["f".concat(Me)]=111+Me;var g=[],oi="all",si=[],xe=function(e){return ni[e.toLowerCase()]||ee[e.toLowerCase()]||e.toUpperCase().charCodeAt(0)};function ri(i){oi=i||"all"}function Ae(){return oi||"all"}function mn(){return g.slice(0)}function An(i){var e=i.target||i.srcElement,t=e.tagName,n=!0;return(e.isContentEditable||(t==="INPUT"||t==="TEXTAREA"||t==="SELECT")&&!e.readOnly)&&(n=!1),n}function On(i){return typeof i=="string"&&(i=xe(i)),g.indexOf(i)!==-1}function Cn(i,e){var t,n;i||(i=Ae());for(var o in S)if(Object.prototype.hasOwnProperty.call(S,o))for(t=S[o],n=0;n<t.length;)t[n].scope===i?t.splice(n,1):n++;Ae()===i&&ri(e||"all")}function wn(i){var e=i.keyCode||i.which||i.charCode,t=g.indexOf(e);if(t>=0&&g.splice(t,1),i.key&&i.key.toLowerCase()==="meta"&&g.splice(0,g.length),(e===93||e===224)&&(e=91),e in E){E[e]=!1;for(var n in ee)ee[n]===e&&(w[n]=!1)}}function Nn(i){if(!i)Object.keys(S).forEach(function(r){return delete S[r]});else if(Array.isArray(i))i.forEach(function(r){r.key&&Ye(r)});else if(typeof i=="object")i.key&&Ye(i);else if(typeof i=="string"){for(var e=arguments.length,t=new Array(e>1?e-1:0),n=1;n<e;n++)t[n-1]=arguments[n];var o=t[0],s=t[1];typeof o=="function"&&(s=o,o=""),Ye({key:i,scope:o,method:s,splitKey:"+"})}}var Ye=function(e){var t=e.key,n=e.scope,o=e.method,s=e.splitKey,r=s===void 0?"+":s,a=ii(t);a.forEach(function(l){var c=l.split(r),h=c.length,d=c[h-1],u=d==="*"?"*":xe(d);if(S[u]){n||(n=Ae());var p=h>1?ti(ee,c):[];S[u]=S[u].map(function(_){var f=o?_.method===o:!0;return f&&_.scope===n&&gn(_.mods,p)?{}:_})}})};function Tt(i,e,t){var n;if(e.scope===t||e.scope==="all"){n=e.mods.length>0;for(var o in E)Object.prototype.hasOwnProperty.call(E,o)&&(!E[o]&&e.mods.indexOf(+o)>-1||E[o]&&e.mods.indexOf(+o)===-1)&&(n=!1);(e.mods.length===0&&!E[16]&&!E[18]&&!E[17]&&!E[91]||n||e.shortcut==="*")&&e.method(i,e)===!1&&(i.preventDefault?i.preventDefault():i.returnValue=!1,i.stopPropagation&&i.stopPropagation(),i.cancelBubble&&(i.cancelBubble=!0))}}function $t(i){var e=S["*"],t=i.keyCode||i.which||i.charCode;if(w.filter.call(this,i)){if((t===93||t===224)&&(t=91),g.indexOf(t)===-1&&t!==229&&g.push(t),["ctrlKey","altKey","shiftKey","metaKey"].forEach(function(p){var _=bt[p];i[p]&&g.indexOf(_)===-1?g.push(_):!i[p]&&g.indexOf(_)>-1?g.splice(g.indexOf(_),1):p==="metaKey"&&i[p]&&g.length===3&&(i.ctrlKey||i.shiftKey||i.altKey||(g=g.slice(g.indexOf(_))))}),t in E){E[t]=!0;for(var n in ee)ee[n]===t&&(w[n]=!0);if(!e)return}for(var o in E)Object.prototype.hasOwnProperty.call(E,o)&&(E[o]=i[bt[o]]);i.getModifierState&&!(i.altKey&&!i.ctrlKey)&&i.getModifierState("AltGraph")&&(g.indexOf(17)===-1&&g.push(17),g.indexOf(18)===-1&&g.push(18),E[17]=!0,E[18]=!0);var s=Ae();if(e)for(var r=0;r<e.length;r++)e[r].scope===s&&(i.type==="keydown"&&e[r].keydown||i.type==="keyup"&&e[r].keyup)&&Tt(i,e[r],s);if(t in S){for(var a=0;a<S[t].length;a++)if((i.type==="keydown"&&S[t][a].keydown||i.type==="keyup"&&S[t][a].keyup)&&S[t][a].key){for(var l=S[t][a],c=l.splitKey,h=l.key.split(c),d=[],u=0;u<h.length;u++)d.push(xe(h[u]));d.sort().join("")===g.sort().join("")&&Tt(i,l,s)}}}}function Mn(i){return si.indexOf(i)>-1}function w(i,e,t){g=[];var n=ii(i),o=[],s="all",r=document,a=0,l=!1,c=!0,h="+";for(t===void 0&&typeof e=="function"&&(t=e),Object.prototype.toString.call(e)==="[object Object]"&&(e.scope&&(s=e.scope),e.element&&(r=e.element),e.keyup&&(l=e.keyup),e.keydown!==void 0&&(c=e.keydown),typeof e.splitKey=="string"&&(h=e.splitKey)),typeof e=="string"&&(s=e);a<n.length;a++)i=n[a].split(h),o=[],i.length>1&&(o=ti(ee,i)),i=i[i.length-1],i=i==="*"?"*":xe(i),i in S||(S[i]=[]),S[i].push({keyup:l,keydown:c,scope:s,mods:o,shortcut:n[a],method:t,key:n[a],splitKey:h});typeof r<"u"&&!Mn(r)&&window&&(si.push(r),Fe(r,"keydown",function(d){$t(d)}),Fe(window,"focus",function(){g=[]}),Fe(r,"keyup",function(d){$t(d),wn(d)}))}var We={setScope:ri,getScope:Ae,deleteScope:Cn,getPressedKeyCodes:mn,isPressed:On,filter:An,unbind:Nn};for(var Xe in We)Object.prototype.hasOwnProperty.call(We,Xe)&&(w[Xe]=We[Xe]);if(typeof window<"u"){var yn=window.hotkeys;w.noConflict=function(i){return i&&window.hotkeys===w&&(window.hotkeys=yn),w},window.hotkeys=w}var we=function(i,e,t,n){var o=arguments.length,s=o<3?e:n===null?n=Object.getOwnPropertyDescriptor(e,t):n,r;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(i,e,t,n);else for(var a=i.length-1;a>=0;a--)(r=i[a])&&(s=(o<3?r(s):o>3?r(e,t,s):r(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let te=class extends z{constructor(){super(...arguments),this.placeholder="",this.hideBreadcrumbs=!1,this.breadcrumbHome="Home",this.breadcrumbs=[],this._inputRef=Qt()}render(){let e="";if(!this.hideBreadcrumbs){const t=[];for(const n of this.breadcrumbs)t.push(b`<button
            tabindex="-1"
            @click=${()=>this.selectParent(n)}
            class="breadcrumb"
          >
            ${n}
          </button>`);e=b`<div class="breadcrumb-list">
        <button
          tabindex="-1"
          @click=${()=>this.selectParent()}
          class="breadcrumb"
        >
          ${this.breadcrumbHome}
        </button>
        ${t}
      </div>`}return b`
      ${e}
      <div part="ninja-input-wrapper" class="search-wrapper">
        <input
          part="ninja-input"
          type="text"
          id="search"
          spellcheck="false"
          autocomplete="off"
          @input="${this._handleInput}"
          ${ei(this._inputRef)}
          placeholder="${this.placeholder}"
          class="search"
        />
      </div>
    `}setSearch(e){this._inputRef.value&&(this._inputRef.value.value=e)}focusSearch(){requestAnimationFrame(()=>this._inputRef.value.focus())}_handleInput(e){const t=e.target;this.dispatchEvent(new CustomEvent("change",{detail:{search:t.value},bubbles:!1,composed:!1}))}selectParent(e){this.dispatchEvent(new CustomEvent("setParent",{detail:{parent:e},bubbles:!0,composed:!0}))}firstUpdated(){this.focusSearch()}_close(){this.dispatchEvent(new CustomEvent("close",{bubbles:!0,composed:!0}))}};te.styles=Te`
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
  `;we([M()],te.prototype,"placeholder",void 0);we([M({type:Boolean})],te.prototype,"hideBreadcrumbs",void 0);we([M()],te.prototype,"breadcrumbHome",void 0);we([M({type:Array})],te.prototype,"breadcrumbs",void 0);te=we([Ie("ninja-header")],te);/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */class nt extends Ce{constructor(e){if(super(e),this.et=A,e.type!==B.CHILD)throw Error(this.constructor.directiveName+"() can only be used in child bindings")}render(e){if(e===A||e==null)return this.ft=void 0,this.et=e;if(e===k)return e;if(typeof e!="string")throw Error(this.constructor.directiveName+"() called with a non-string value");if(e===this.et)return this.ft;this.et=e;const t=[e];return t.raw=t,this.ft={_$litType$:this.constructor.resultType,strings:t,values:[]}}}nt.directiveName="unsafeHTML",nt.resultType=1;const Sn=Oe(nt);/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */function*En(i,e){if(i!==void 0){let t=-1;for(const n of i)t>-1&&(yield e),t++,yield n}}/**
 * @license
 * Copyright 2021 Google LLC
 * SPDX-LIcense-Identifier: Apache-2.0
 */const bn=Te`:host{font-family:var(--mdc-icon-font, "Material Icons");font-weight:normal;font-style:normal;font-size:var(--mdc-icon-size, 24px);line-height:1;letter-spacing:normal;text-transform:none;display:inline-block;white-space:nowrap;word-wrap:normal;direction:ltr;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;-moz-osx-font-smoothing:grayscale;font-feature-settings:"liga"}`;/**
 * @license
 * Copyright 2018 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */let ot=class extends z{render(){return b`<span><slot></slot></span>`}};ot.styles=[bn];ot=wi([Ie("mwc-icon")],ot);var Re=function(i,e,t,n){var o=arguments.length,s=o<3?e:n===null?n=Object.getOwnPropertyDescriptor(e,t):n,r;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(i,e,t,n);else for(var a=i.length-1;a>=0;a--)(r=i[a])&&(s=(o<3?r(s):o>3?r(e,t,s):r(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let re=class extends z{constructor(){super(),this.selected=!1,this.hotKeysJoinedView=!0,this.addEventListener("click",this.click)}ensureInView(){requestAnimationFrame(()=>this.scrollIntoView({block:"nearest"}))}click(){this.dispatchEvent(new CustomEvent("actionsSelected",{detail:this.action,bubbles:!0,composed:!0}))}updated(e){e.has("selected")&&this.selected&&this.ensureInView()}render(){let e;this.action.mdIcon?e=b`<mwc-icon part="ninja-icon" class="ninja-icon"
        >${this.action.mdIcon}</mwc-icon
      >`:this.action.icon&&(e=Sn(this.action.icon||""));let t;this.action.hotkey&&(this.hotKeysJoinedView?t=this.action.hotkey.split(",").map(o=>{const s=o.split("+"),r=b`${En(s.map(a=>b`<kbd>${a}</kbd>`),"+")}`;return b`<div class="ninja-hotkey ninja-hotkeys">
            ${r}
          </div>`}):t=this.action.hotkey.split(",").map(o=>{const r=o.split("+").map(a=>b`<kbd class="ninja-hotkey">${a}</kbd>`);return b`<kbd class="ninja-hotkeys">${r}</kbd>`}));const n={selected:this.selected,"ninja-action":!0};return b`
      <div
        class="ninja-action"
        part="ninja-action ${this.selected?"ninja-selected":""}"
        class=${it(n)}
      >
        ${e}
        <div class="ninja-title">${this.action.title}</div>
        ${t}
      </div>
    `}};re.styles=Te`
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
  `;Re([M({type:Object})],re.prototype,"action",void 0);Re([M({type:Boolean})],re.prototype,"selected",void 0);Re([M({type:Boolean})],re.prototype,"hotKeysJoinedView",void 0);re=Re([Ie("ninja-action")],re);const Tn=b` <div class="modal-footer" slot="footer">
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
</div>`,$n=Te`
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
`;var N=function(i,e,t,n){var o=arguments.length,s=o<3?e:n===null?n=Object.getOwnPropertyDescriptor(e,t):n,r;if(typeof Reflect=="object"&&typeof Reflect.decorate=="function")s=Reflect.decorate(i,e,t,n);else for(var a=i.length-1;a>=0;a--)(r=i[a])&&(s=(o<3?r(s):o>3?r(e,t,s):r(e,t))||s);return o>3&&s&&Object.defineProperty(e,t,s),s};let O=class extends z{constructor(){super(...arguments),this.placeholder="Type a command or search...",this.disableHotkeys=!1,this.hideBreadcrumbs=!1,this.openHotkey="cmd+k,ctrl+k",this.navigationUpHotkey="up,shift+tab",this.navigationDownHotkey="down,tab",this.closeHotkey="esc",this.goBackHotkey="backspace",this.selectHotkey="enter",this.hotKeysJoinedView=!1,this.noAutoLoadMdIcons=!1,this.data=[],this.visible=!1,this._bump=!0,this._actionMatches=[],this._search="",this._flatData=[],this._headerRef=Qt()}open(e={}){this._bump=!0,this.visible=!0,this._headerRef.value.focusSearch(),this._actionMatches.length>0&&(this._selected=this._actionMatches[0]),this.setParent(e.parent)}close(){this._bump=!1,this.visible=!1,this.dispatchEvent(new CustomEvent("closed",{bubbles:!0,composed:!0}))}setParent(e){e?this._currentRoot=e:this._currentRoot=void 0,this._selected=void 0,this._search="",this._headerRef.value.setSearch("")}get breadcrumbs(){var e;const t=[];let n=(e=this._selected)===null||e===void 0?void 0:e.parent;if(n)for(t.push(n);n;){const o=this._flatData.find(s=>s.id===n);o!=null&&o.parent&&t.push(o.parent),n=o?o.parent:void 0}return t.reverse()}connectedCallback(){super.connectedCallback(),this.noAutoLoadMdIcons||document.fonts.load("24px Material Icons","apps").then(()=>{}),this._registerInternalHotkeys()}disconnectedCallback(){super.disconnectedCallback(),this._unregisterInternalHotkeys()}_flattern(e,t){let n=[];return e||(e=[]),e.map(o=>{const s=o.children&&o.children.some(a=>typeof a=="string"),r={...o,parent:o.parent||t};return s||(r.children&&r.children.length&&(t=o.id,n=[...n,...r.children]),r.children=r.children?r.children.map(a=>a.id):[]),r}).concat(n.length?this._flattern(n,t):n)}update(e){e.has("data")&&!this.disableHotkeys&&(this._flatData=this._flattern(this.data),this._flatData.filter(t=>!!t.hotkey).forEach(t=>{w(t.hotkey,n=>{n.preventDefault(),t.handler&&t.handler(t)})})),super.update(e)}_registerInternalHotkeys(){this.openHotkey&&w(this.openHotkey,e=>{e.preventDefault(),this.visible?this.close():this.open()}),this.selectHotkey&&w(this.selectHotkey,e=>{this.visible&&(e.preventDefault(),this._actionSelected(this._actionMatches[this._selectedIndex]))}),this.goBackHotkey&&w(this.goBackHotkey,e=>{this.visible&&(this._search||(e.preventDefault(),this._goBack()))}),this.navigationDownHotkey&&w(this.navigationDownHotkey,e=>{this.visible&&(e.preventDefault(),this._selectedIndex>=this._actionMatches.length-1?this._selected=this._actionMatches[0]:this._selected=this._actionMatches[this._selectedIndex+1])}),this.navigationUpHotkey&&w(this.navigationUpHotkey,e=>{this.visible&&(e.preventDefault(),this._selectedIndex===0?this._selected=this._actionMatches[this._actionMatches.length-1]:this._selected=this._actionMatches[this._selectedIndex-1])}),this.closeHotkey&&w(this.closeHotkey,()=>{this.visible&&this.close()})}_unregisterInternalHotkeys(){this.openHotkey&&w.unbind(this.openHotkey),this.selectHotkey&&w.unbind(this.selectHotkey),this.goBackHotkey&&w.unbind(this.goBackHotkey),this.navigationDownHotkey&&w.unbind(this.navigationDownHotkey),this.navigationUpHotkey&&w.unbind(this.navigationUpHotkey),this.closeHotkey&&w.unbind(this.closeHotkey)}_actionFocused(e,t){this._selected=e,t.target.ensureInView()}_onTransitionEnd(){this._bump=!1}_goBack(){const e=this.breadcrumbs.length>1?this.breadcrumbs[this.breadcrumbs.length-2]:void 0;this.setParent(e)}render(){const e={bump:this._bump,"modal-content":!0},t={visible:this.visible,modal:!0},o=this._flatData.filter(a=>{var l;const c=new RegExp(this._search,"gi"),h=a.title.match(c)||((l=a.keywords)===null||l===void 0?void 0:l.match(c));return(!this._currentRoot&&this._search||a.parent===this._currentRoot)&&h}).reduce((a,l)=>a.set(l.section,[...a.get(l.section)||[],l]),new Map);this._actionMatches=[...o.values()].flat(),this._actionMatches.length>0&&this._selectedIndex===-1&&(this._selected=this._actionMatches[0]),this._actionMatches.length===0&&(this._selected=void 0);const s=a=>b` ${hn(a,l=>l.id,l=>{var c;return b`<ninja-action
            exportparts="ninja-action,ninja-selected,ninja-icon"
            .selected=${dn(l.id===((c=this._selected)===null||c===void 0?void 0:c.id))}
            .hotKeysJoinedView=${this.hotKeysJoinedView}
            @mouseover=${h=>this._actionFocused(l,h)}
            @actionsSelected=${h=>this._actionSelected(h.detail)}
            .action=${l}
          ></ninja-action>`})}`,r=[];return o.forEach((a,l)=>{const c=l?b`<div class="group-header">${l}</div>`:void 0;r.push(b`${c}${s(a)}`)}),b`
      <div @click=${this._overlayClick} class=${it(t)}>
        <div class=${it(e)} @animationend=${this._onTransitionEnd}>
          <ninja-header
            exportparts="ninja-input,ninja-input-wrapper"
            ${ei(this._headerRef)}
            .placeholder=${this.placeholder}
            .hideBreadcrumbs=${this.hideBreadcrumbs}
            .breadcrumbs=${this.breadcrumbs}
            @change=${this._handleInput}
            @setParent=${a=>this.setParent(a.detail.parent)}
            @close=${this.close}
          >
          </ninja-header>
          <div class="modal-body">
            <div class="actions-list" part="actions-list">${r}</div>
          </div>
          <slot name="footer"> ${Tn} </slot>
        </div>
      </div>
    `}get _selectedIndex(){return this._selected?this._actionMatches.indexOf(this._selected):-1}_actionSelected(e){var t;if(this.dispatchEvent(new CustomEvent("selected",{detail:{search:this._search,action:e},bubbles:!0,composed:!0})),!!e){if(e.children&&((t=e.children)===null||t===void 0?void 0:t.length)>0&&(this._currentRoot=e.id,this._search=""),this._headerRef.value.setSearch(""),this._headerRef.value.focusSearch(),e.handler){const n=e.handler(e);n!=null&&n.keepOpen||this.close()}this._bump=!0}}async _handleInput(e){this._search=e.detail.search,await this.updateComplete,this.dispatchEvent(new CustomEvent("change",{detail:{search:this._search,actions:this._actionMatches},bubbles:!0,composed:!0}))}_overlayClick(e){var t;!((t=e.target)===null||t===void 0)&&t.classList.contains("modal")&&this.close()}};O.styles=[$n];N([M({type:String})],O.prototype,"placeholder",void 0);N([M({type:Boolean})],O.prototype,"disableHotkeys",void 0);N([M({type:Boolean})],O.prototype,"hideBreadcrumbs",void 0);N([M()],O.prototype,"openHotkey",void 0);N([M()],O.prototype,"navigationUpHotkey",void 0);N([M()],O.prototype,"navigationDownHotkey",void 0);N([M()],O.prototype,"closeHotkey",void 0);N([M()],O.prototype,"goBackHotkey",void 0);N([M()],O.prototype,"selectHotkey",void 0);N([M({type:Boolean})],O.prototype,"hotKeysJoinedView",void 0);N([M({type:Boolean})],O.prototype,"noAutoLoadMdIcons",void 0);N([M({type:Array,hasChanged(){return!0}})],O.prototype,"data",void 0);N([F()],O.prototype,"visible",void 0);N([F()],O.prototype,"_bump",void 0);N([F()],O.prototype,"_actionMatches",void 0);N([F()],O.prototype,"_search",void 0);N([F()],O.prototype,"_currentRoot",void 0);N([F()],O.prototype,"_flatData",void 0);N([F()],O.prototype,"breadcrumbs",null);N([F()],O.prototype,"_selected",void 0);O=N([Ie("ninja-keys")],O);const It='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 2A2.25 2.25 0 0 1 22 4.25v5.462a3.25 3.25 0 0 1-.952 2.298l-8.5 8.503a3.255 3.255 0 0 1-4.597.001L3.489 16.06a3.25 3.25 0 0 1-.003-4.596l8.5-8.51A3.25 3.25 0 0 1 14.284 2h5.465Zm0 1.5h-5.465c-.465 0-.91.185-1.239.513l-8.512 8.523a1.75 1.75 0 0 0 .015 2.462l4.461 4.454a1.755 1.755 0 0 0 2.477 0l8.5-8.503a1.75 1.75 0 0 0 .513-1.237V4.25a.75.75 0 0 0-.75-.75ZM17 5.502a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Z" fill="currentColor"/></svg>',In='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12.92 3.316c.806-.717 2.08-.145 2.08.934v15.496c0 1.078-1.274 1.65-2.08.934l-4.492-3.994a.75.75 0 0 0-.498-.19H4.25A2.25 2.25 0 0 1 2 14.247V9.75a2.25 2.25 0 0 1 2.25-2.25h3.68a.75.75 0 0 0 .498-.19l4.491-3.993Zm.58 1.49L9.425 8.43A2.25 2.25 0 0 1 7.93 9H4.25a.75.75 0 0 0-.75.75v4.497c0 .415.336.75.75.75h3.68a2.25 2.25 0 0 1 1.495.57l4.075 3.623V4.807ZM16.22 9.22a.75.75 0 0 1 1.06 0L19 10.94l1.72-1.72a.75.75 0 1 1 1.06 1.06L20.06 12l1.72 1.72a.75.75 0 1 1-1.06 1.06L19 13.06l-1.72 1.72a.75.75 0 1 1-1.06-1.06L17.94 12l-1.72-1.72a.75.75 0 0 1 0-1.06Z" fill="currentColor"/></svg>',xn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M15 4.25c0-1.079-1.274-1.65-2.08-.934L8.427 7.309a.75.75 0 0 1-.498.19H4.25A2.25 2.25 0 0 0 2 9.749v4.497a2.25 2.25 0 0 0 2.25 2.25h3.68a.75.75 0 0 1 .498.19l4.491 3.994c.806.716 2.081.144 2.081-.934V4.25ZM9.425 8.43 13.5 4.807v14.382l-4.075-3.624a2.25 2.25 0 0 0-1.495-.569H4.25a.75.75 0 0 1-.75-.75V9.75a.75.75 0 0 1 .75-.75h3.68a2.25 2.25 0 0 0 1.495-.569ZM18.992 5.897a.75.75 0 0 1 1.049.157A9.959 9.959 0 0 1 22 12a9.96 9.96 0 0 1-1.96 5.946.75.75 0 0 1-1.205-.892A8.459 8.459 0 0 0 20.5 12a8.459 8.459 0 0 0-1.665-5.054.75.75 0 0 1 .157-1.049Z" fill="#212121"/><path d="M17.143 8.37a.75.75 0 0 1 1.017.302c.536.99.84 2.125.84 3.328a6.973 6.973 0 0 1-.84 3.328.75.75 0 0 1-1.32-.714c.42-.777.66-1.666.66-2.614s-.24-1.837-.66-2.614a.75.75 0 0 1 .303-1.017Z" fill="currentColor"/></svg>',xt='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 2A2.25 2.25 0 0 1 22 4.25v5.462a3.25 3.25 0 0 1-.952 2.298l-.026.026a6.473 6.473 0 0 0-1.43-.692l.395-.395a1.75 1.75 0 0 0 .513-1.237V4.25a.75.75 0 0 0-.75-.75h-5.466c-.464 0-.91.185-1.238.513l-8.512 8.523a1.75 1.75 0 0 0 .015 2.462l4.461 4.454a1.755 1.755 0 0 0 2.33.13c.165.487.386.947.654 1.374a3.256 3.256 0 0 1-4.043-.442L3.489 16.06a3.25 3.25 0 0 1-.004-4.596l8.5-8.51a3.25 3.25 0 0 1 2.3-.953h5.465ZM17 5.502a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM17.5 23a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11Zm-2.354-7.854a.5.5 0 0 1 .708 0l1.646 1.647 1.646-1.647a.5.5 0 0 1 .708.708L18.207 17.5l1.647 1.646a.5.5 0 0 1-.708.708L17.5 18.207l-1.646 1.647a.5.5 0 0 1-.708-.708l1.647-1.646-1.647-1.646a.5.5 0 0 1 0-.708Z" fill="currentColor"/></svg>',Rn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.75 11.5a.75.75 0 0 1 .743.648l.007.102v5a4.75 4.75 0 0 1-4.533 4.745L15.75 22h-7.5c-.98 0-1.813-.626-2.122-1.5h9.622l.184-.005a3.25 3.25 0 0 0 3.06-3.06L19 17.25v-5a.75.75 0 0 1 .75-.75Zm-2.5-2a.75.75 0 0 1 .743.648l.007.102v7a2.25 2.25 0 0 1-2.096 2.245l-.154.005h-10a2.25 2.25 0 0 1-2.245-2.096L3.5 17.25v-7a.75.75 0 0 1 1.493-.102L5 10.25v7c0 .38.282.694.648.743L5.75 18h10a.75.75 0 0 0 .743-.648l.007-.102v-7a.75.75 0 0 1 .75-.75ZM6.218 6.216l3.998-3.996a.75.75 0 0 1 .976-.073l.084.072 4.004 3.997a.75.75 0 0 1-.976 1.134l-.084-.073-2.72-2.714v9.692a.75.75 0 0 1-.648.743l-.102.007a.75.75 0 0 1-.743-.648L10 14.255V4.556L7.279 7.277a.75.75 0 0 1-.977.072l-.084-.072a.75.75 0 0 1-.072-.977l.072-.084 3.998-3.996-3.998 3.996Z" fill="currentColor"/></svg>',kn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 2c5.523 0 10 4.478 10 10s-4.477 10-10 10S2 17.522 2 12S6.477 2 12 2Zm0 1.667c-4.595 0-8.333 3.738-8.333 8.333c0 4.595 3.738 8.333 8.333 8.333c4.595 0 8.333-3.738 8.333-8.333c0-4.595-3.738-8.333-8.333-8.333ZM11.25 6a.75.75 0 0 1 .743.648L12 6.75V12h3.25a.75.75 0 0 1 .102 1.493l-.102.007h-4a.75.75 0 0 1-.743-.648l-.007-.102v-6a.75.75 0 0 1 .75-.75Z" fill="currentColor"/></svg>',jn='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 20 20"><path fill="currentColor" d="M9.562 3.262a.5.5 0 0 1 .879 0l6.5 12a.5.5 0 0 1-.44.739H3.5a.5.5 0 0 1-.44-.739l6.503-12Zm1.758-.477c-.567-1.047-2.07-1.047-2.638 0L2.18 14.786a1.5 1.5 0 0 0 1.32 2.215h13.002a1.5 1.5 0 0 0 1.319-2.215l-6.5-12ZM10.5 7.5a.5.5 0 1 0-1 0v4a.5.5 0 0 0 1 0v-4Zm.25 6.25a.75.75 0 1 1-1.5 0a.75.75 0 0 1 1.5 0Z"/></svg>',Dn=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#FFEBEE"/>
<path d="M8 8.5C8 7.94772 8.44772 7.5 9 7.5C9.55228 7.5 10 7.94772 10 8.5V13C10 13.5523 9.55228 14 9 14C8.44772 14 8 13.5523 8 13V8.5Z" fill="#FF382D"/>
<path d="M8 15.5C8 14.9477 8.44772 14.5 9 14.5C9.55228 14.5 10 14.9477 10 15.5C10 16.0523 9.55228 16.5 9 16.5C8.44772 16.5 8 16.0523 8 15.5Z" fill="#FF382D"/>
<path d="M11 8.5C11 7.94772 11.4477 7.5 12 7.5C12.5523 7.5 13 7.94772 13 8.5V13C13 13.5523 12.5523 14 12 14C11.4477 14 11 13.5523 11 13V8.5Z" fill="#FF382D"/>
<path d="M11 15.5C11 14.9477 11.4477 14.5 12 14.5C12.5523 14.5 13 14.9477 13 15.5C13 16.0523 12.5523 16.5 12 16.5C11.4477 16.5 11 16.0523 11 15.5Z" fill="#FF382D"/>
<path d="M14 8.5C14 7.94772 14.4477 7.5 15 7.5C15.5523 7.5 16 7.94772 16 8.5V13C16 13.5523 15.5523 14 15 14C14.4477 14 14 13.5523 14 13V8.5Z" fill="#FF382D"/>
<path d="M14 15.5C14 14.9477 14.4477 14.5 15 14.5C15.5523 14.5 16 14.9477 16 15.5C16 16.0523 15.5523 16.5 15 16.5C14.4477 16.5 14 16.0523 14 15.5Z" fill="#FF382D"/>
</svg>
`,Bn=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M9.7642 8L9.62358 14.1619H8.25142L8.11506 8H9.7642ZM8.9375 16.821C8.67898 16.821 8.45739 16.7301 8.27273 16.5483C8.09091 16.3665 8 16.1449 8 15.8835C8 15.6278 8.09091 15.4091 8.27273 15.2273C8.45739 15.0455 8.67898 14.9545 8.9375 14.9545C9.19034 14.9545 9.40909 15.0455 9.59375 15.2273C9.78125 15.4091 9.875 15.6278 9.875 15.8835C9.875 16.0568 9.83097 16.2145 9.7429 16.3565C9.65767 16.4986 9.54403 16.6122 9.40199 16.6974C9.26278 16.7798 9.10795 16.821 8.9375 16.821Z" fill="#446888"/>
<path d="M13.1073 8L12.9667 14.1619H11.5945L11.4582 8H13.1073ZM12.2806 16.821C12.0221 16.821 11.8005 16.7301 11.6159 16.5483C11.434 16.3665 11.3431 16.1449 11.3431 15.8835C11.3431 15.6278 11.434 15.4091 11.6159 15.2273C11.8005 15.0455 12.0221 14.9545 12.2806 14.9545C12.5335 14.9545 12.7522 15.0455 12.9369 15.2273C13.1244 15.4091 13.2181 15.6278 13.2181 15.8835C13.2181 16.0568 13.1741 16.2145 13.086 16.3565C13.0008 16.4986 12.8872 16.6122 12.7451 16.6974C12.6059 16.7798 12.4511 16.821 12.2806 16.821Z" fill="#446888"/>
<path d="M16.4505 8L16.3098 14.1619H14.9377L14.8013 8H16.4505ZM15.6237 16.821C15.3652 16.821 15.1436 16.7301 14.959 16.5483C14.7772 16.3665 14.6862 16.1449 14.6862 15.8835C14.6862 15.6278 14.7772 15.4091 14.959 15.2273C15.1436 15.0455 15.3652 14.9545 15.6237 14.9545C15.8766 14.9545 16.0953 15.0455 16.28 15.2273C16.4675 15.4091 16.5612 15.6278 16.5612 15.8835C16.5612 16.0568 16.5172 16.2145 16.4291 16.3565C16.3439 16.4986 16.2303 16.6122 16.0882 16.6974C15.949 16.7798 15.7942 16.821 15.6237 16.821Z" fill="#446888"/>
</svg>`,Hn=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M10.7642 8L10.6236 14.1619H9.25142L9.11506 8H10.7642ZM9.9375 16.821C9.67898 16.821 9.45739 16.7301 9.27273 16.5483C9.09091 16.3665 9 16.1449 9 15.8835C9 15.6278 9.09091 15.4091 9.27273 15.2273C9.45739 15.0455 9.67898 14.9545 9.9375 14.9545C10.1903 14.9545 10.4091 15.0455 10.5938 15.2273C10.7812 15.4091 10.875 15.6278 10.875 15.8835C10.875 16.0568 10.831 16.2145 10.7429 16.3565C10.6577 16.4986 10.544 16.6122 10.402 16.6974C10.2628 16.7798 10.108 16.821 9.9375 16.821Z" fill="#446888"/>
<path d="M14.1073 8L13.9667 14.1619H12.5945L12.4582 8H14.1073ZM13.2806 16.821C13.0221 16.821 12.8005 16.7301 12.6159 16.5483C12.434 16.3665 12.3431 16.1449 12.3431 15.8835C12.3431 15.6278 12.434 15.4091 12.6159 15.2273C12.8005 15.0455 13.0221 14.9545 13.2806 14.9545C13.5335 14.9545 13.7522 15.0455 13.9369 15.2273C14.1244 15.4091 14.2181 15.6278 14.2181 15.8835C14.2181 16.0568 14.1741 16.2145 14.086 16.3565C14.0008 16.4986 13.8872 16.6122 13.7451 16.6974C13.6059 16.7798 13.4511 16.821 13.2806 16.821Z" fill="#446888"/>
</svg>`,Ln=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M12.7642 8L12.6236 14.1619H11.2514L11.1151 8H12.7642ZM11.9375 16.821C11.679 16.821 11.4574 16.7301 11.2727 16.5483C11.0909 16.3665 11 16.1449 11 15.8835C11 15.6278 11.0909 15.4091 11.2727 15.2273C11.4574 15.0455 11.679 14.9545 11.9375 14.9545C12.1903 14.9545 12.4091 15.0455 12.5938 15.2273C12.7812 15.4091 12.875 15.6278 12.875 15.8835C12.875 16.0568 12.831 16.2145 12.7429 16.3565C12.6577 16.4986 12.544 16.6122 12.402 16.6974C12.2628 16.7798 12.108 16.821 11.9375 16.821Z" fill="#446888"/>
</svg>`,Pn=`<svg role="img" class="ninja-icon ninja-icon--fluent" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect width="24" height="24" fill="#F1F5F8"/>
<path d="M13.5686 8L11.1579 16.9562H10L12.4107 8H13.5686Z" fill="#446888"/>
</svg>`,ve='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="m13.314 7.565l-.136.126l-10.48 10.488a2.27 2.27 0 0 0 3.211 3.208L16.388 10.9a2.251 2.251 0 0 0-.001-3.182l-.157-.146a2.25 2.25 0 0 0-2.916-.007Zm-.848 2.961l1.088 1.088l-8.706 8.713a.77.77 0 1 1-1.089-1.088l8.707-8.713Zm4.386 4.48L16.75 15a.75.75 0 0 0-.743.648L16 15.75v.75h-.75a.75.75 0 0 0-.743.648l-.007.102c0 .38.282.694.648.743l.102.007H16v.75c0 .38.282.694.648.743l.102.007a.75.75 0 0 0 .743-.648l.007-.102V18h.75a.75.75 0 0 0 .743-.648L19 17.25a.75.75 0 0 0-.648-.743l-.102-.007h-.75v-.75a.75.75 0 0 0-.648-.743L16.75 15l.102.007Zm-1.553-6.254l.027.027a.751.751 0 0 1 0 1.061l-.711.713l-1.089-1.089l.73-.73a.75.75 0 0 1 1.043.018ZM6.852 5.007L6.75 5a.75.75 0 0 0-.743.648L6 5.75v.75h-.75a.75.75 0 0 0-.743.648L4.5 7.25c0 .38.282.693.648.743L5.25 8H6v.75c0 .38.282.693.648.743l.102.007a.75.75 0 0 0 .743-.648L7.5 8.75V8h.75a.75.75 0 0 0 .743-.648L9 7.25a.75.75 0 0 0-.648-.743L8.25 6.5H7.5v-.75a.75.75 0 0 0-.648-.743L6.75 5l.102.007Zm12-2L18.75 3a.75.75 0 0 0-.743.648L18 3.75v.75h-.75a.75.75 0 0 0-.743.648l-.007.102c0 .38.282.693.648.743L17.25 6H18v.75c0 .38.282.693.648.743l.102.007a.75.75 0 0 0 .743-.648l.007-.102V6h.75a.75.75 0 0 0 .743-.648L21 5.25a.75.75 0 0 0-.648-.743L20.25 4.5h-.75v-.75a.75.75 0 0 0-.648-.743L18.75 3l.102.007Z" fill="currentColor"/></svg>',Zn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H18a2.5 2.5 0 0 1 2.5 2.5v14.25a.75.75 0 0 1-.75.75H5.5a1 1 0 0 0 1 1h13.25a.75.75 0 0 1 0 1.5H6.5A2.5 2.5 0 0 1 4 19.5v-15ZM5.5 18H19V4.5a1 1 0 0 0-1-1H6.5a1 1 0 0 0-1 1V18Z" fill="currentColor"/></svg>',Un='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M6.75 19.5h14.5a.75.75 0 0 0 .102-1.493L21.25 18H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm0-15h14.5a.75.75 0 0 0 .102-1.493L21.25 3H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm7 3.5a.75.75 0 0 0 0 1.5h7.5a.75.75 0 0 0 0-1.5h-7.5ZM13 13.75a.75.75 0 0 1 .75-.75h7.5a.75.75 0 0 1 0 1.5h-7.5a.75.75 0 0 1-.75-.75Zm-2-2.25a4.5 4.5 0 1 1-9 0a4.5 4.5 0 0 1 9 0Zm-4-2a.5.5 0 0 0-1 0V11H4.5a.5.5 0 0 0 0 1H6v1.5a.5.5 0 0 0 1 0V12h1.5a.5.5 0 0 0 0-1H7V9.5Z" fill="currentColor"/></svg>',Gn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M6.75 4.5h14.5a.75.75 0 0 0 .102-1.493L21.25 3H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm0 15h14.5a.75.75 0 0 0 .102-1.493L21.25 18H6.75a.75.75 0 0 0-.102 1.493l.102.007Zm7-11.5a.75.75 0 0 0 0 1.5h7.5a.75.75 0 0 0 0-1.5h-7.5ZM13 13.75a.75.75 0 0 1 .75-.75h7.5a.75.75 0 0 1 0 1.5h-7.5a.75.75 0 0 1-.75-.75Zm-2-2.25a4.5 4.5 0 1 1-9 0a4.5 4.5 0 0 1 9 0Zm-2 0a.5.5 0 0 0-.5-.5h-4a.5.5 0 0 0 0 1h4a.5.5 0 0 0 .5-.5Z" fill="currentColor"/></svg>',Vn='<svg role="img" class="ninja-icon ninja-icon--fluent" width="18" height="18" fill="none" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M3 17h7.522l-2 2H3a1 1 0 0 1-.117-1.993L3 17Zm0-2h7.848a1.75 1.75 0 0 1-.775-2H3l-.117.007A1 1 0 0 0 3 15Zm0-8h18l.117-.007A1 1 0 0 0 21 5H3l-.117.007A1 1 0 0 0 3 7Zm9.72 9.216a.75.75 0 1 1 1.06 1.06l-4.5 4.5a.75.75 0 1 1-1.06-1.06l4.5-4.5ZM3 9h10a1 1 0 0 1 .117 1.993L13 11H3a1 1 0 0 1-.117-1.993L3 9Zm13.5-1a.75.75 0 0 1 .744.658l.14 1.13a3.25 3.25 0 0 0 2.828 2.829l1.13.139a.75.75 0 0 1 0 1.488l-1.13.14a3.25 3.25 0 0 0-2.829 2.828l-.139 1.13a.75.75 0 0 1-1.488 0l-.14-1.13a3.25 3.25 0 0 0-2.828-2.829l-1.13-.139a.75.75 0 0 1 0-1.488l1.13-.14a3.25 3.25 0 0 0 2.829-2.828l.139-1.13A.75.75 0 0 1 16.5 8Z" fill="currentColor"/></svg>',Kn='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18"viewBox="0 0 24 24"><path fill="currentColor" d="M3.839 5.858c2.94-3.916 9.03-5.055 13.364-2.36c4.28 2.66 5.854 7.777 4.1 12.577c-1.655 4.533-6.016 6.328-9.159 4.048c-1.177-.854-1.634-1.925-1.854-3.664l-.106-.987l-.045-.398c-.123-.934-.311-1.352-.705-1.572c-.535-.298-.892-.305-1.595-.033l-.351.146l-.179.078c-1.014.44-1.688.595-2.541.416l-.2-.047l-.164-.047c-2.789-.864-3.202-4.647-.565-8.157Zm.984 6.716l.123.037l.134.03c.439.087.814.015 1.437-.242l.602-.257c1.202-.493 1.985-.54 3.046.05c.917.512 1.275 1.298 1.457 2.66l.053.459l.055.532l.047.422c.172 1.361.485 2.09 1.248 2.644c2.275 1.65 5.534.309 6.87-3.349c1.516-4.152.174-8.514-3.484-10.789c-3.675-2.284-8.899-1.306-11.373 1.987c-2.075 2.763-1.82 5.28-.215 5.816Zm11.225-1.994a1.25 1.25 0 1 1 2.414-.647a1.25 1.25 0 0 1-2.414.647Zm.494 3.488a1.25 1.25 0 1 1 2.415-.647a1.25 1.25 0 0 1-2.415.647ZM14.07 7.577a1.25 1.25 0 1 1 2.415-.647a1.25 1.25 0 0 1-2.415.647Zm-.028 8.998a1.25 1.25 0 1 1 2.414-.647a1.25 1.25 0 0 1-2.414.647Zm-3.497-9.97a1.25 1.25 0 1 1 2.415-.646a1.25 1.25 0 0 1-2.415.646Z"/></svg>',zn='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 12 2Zm5 10a5 5 0 1 1-10 0a5 5 0 0 1 10 0Zm4.25.75a.75.75 0 0 0 0-1.5h-1.5a.75.75 0 0 0 0 1.5h1.5ZM12 19a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 12 19Zm-7.75-6.25a.75.75 0 0 0 0-1.5h-1.5a.75.75 0 0 0 0 1.5h1.5Zm-.03-8.53a.75.75 0 0 1 1.06 0l1.5 1.5a.75.75 0 0 1-1.06 1.06l-1.5-1.5a.75.75 0 0 1 0-1.06Zm1.06 15.56a.75.75 0 1 1-1.06-1.06l1.5-1.5a.75.75 0 1 1 1.06 1.06l-1.5 1.5Zm14.5-15.56a.75.75 0 0 0-1.06 0l-1.5 1.5a.75.75 0 0 0 1.06 1.06l1.5-1.5a.75.75 0 0 0 0-1.06Zm-1.06 15.56a.75.75 0 1 0 1.06-1.06l-1.5-1.5a.75.75 0 1 0-1.06 1.06l1.5 1.5Z"/></svg>',Fn='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M20.026 17.001c-2.762 4.784-8.879 6.423-13.663 3.661A9.965 9.965 0 0 1 3.13 17.68a.75.75 0 0 1 .365-1.132c3.767-1.348 5.785-2.91 6.956-5.146c1.232-2.353 1.551-4.93.689-8.463a.75.75 0 0 1 .769-.927a9.961 9.961 0 0 1 4.457 1.327c4.784 2.762 6.423 8.879 3.66 13.662Zm-8.248-4.903c-1.25 2.389-3.31 4.1-6.817 5.499a8.49 8.49 0 0 0 2.152 1.766a8.502 8.502 0 0 0 8.502-14.725a8.484 8.484 0 0 0-2.792-1.015c.647 3.384.23 6.043-1.045 8.475Z"/></svg>',Yn='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M4.25 3A2.25 2.25 0 0 0 2 5.25v10.5A2.25 2.25 0 0 0 4.25 18H9.5v1.25c0 .69-.56 1.25-1.25 1.25h-.5a.75.75 0 0 0 0 1.5h8.5a.75.75 0 0 0 0-1.5h-.5c-.69 0-1.25-.56-1.25-1.25V18h5.25A2.25 2.25 0 0 0 22 15.75V5.25A2.25 2.25 0 0 0 19.75 3H4.25ZM13 18v1.25c0 .45.108.875.3 1.25h-2.6c.192-.375.3-.8.3-1.25V18h2ZM3.5 5.25a.75.75 0 0 1 .75-.75h15.5a.75.75 0 0 1 .75.75V13h-17V5.25Zm0 9.25h17v1.25a.75.75 0 0 1-.75.75H4.25a.75.75 0 0 1-.75-.75V14.5Z"/></svg>',ie='<svg role="img" class="ninja-icon ninja-icon--fluent" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M12 3.5c-3.104 0-6 2.432-6 6.25v4.153L4.682 17h14.67l-1.354-3.093V11.75a.75.75 0 0 1 1.5 0v1.843l1.381 3.156a1.25 1.25 0 0 1-1.145 1.751H15a3.002 3.002 0 0 1-6.003 0H4.305a1.25 1.25 0 0 1-1.15-1.739l1.344-3.164V9.75C4.5 5.068 8.103 2 12 2c.86 0 1.705.15 2.5.432a.75.75 0 0 1-.502 1.413A5.964 5.964 0 0 0 12 3.5ZM12 20c.828 0 1.5-.671 1.501-1.5h-3.003c0 .829.673 1.5 1.502 1.5Zm3.25-13h-2.5l-.101.007A.75.75 0 0 0 12.75 8.5h1.043l-1.653 2.314l-.055.09A.75.75 0 0 0 12.75 12h2.5l.102-.007a.75.75 0 0 0-.102-1.493h-1.042l1.653-2.314l.055-.09A.75.75 0 0 0 15.25 7Zm6-5h-3.5l-.101.007A.75.75 0 0 0 17.75 3.5h2.134l-2.766 4.347l-.05.09A.75.75 0 0 0 17.75 9h3.5l.102-.007A.75.75 0 0 0 21.25 7.5h-2.133l2.766-4.347l.05-.09A.75.75 0 0 0 21.25 2Z"/></svg>',Je='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11"/></g></svg>',Rt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092a10 10 0 1 0-4.777-4.719"/></svg>',Wn='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 2v2M7 22v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2M8 2v2"/><circle cx="12" cy="11" r="3"/><rect width="18" height="18" x="3" y="4" rx="2"/></g></svg>',kt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2m16 0h2m-7-1v2m-6-2v2"/></g></svg>',Xn='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233a14 14 0 0 0 6.392 6.384"/></svg>',Jn='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M11 6a13 13 0 0 0 8.4-2.8A1 1 0 0 1 21 4v12a1 1 0 0 1-1.6.8A13 13 0 0 0 11 14H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/><path d="M6 14a12 12 0 0 0 2.4 7.2a2 2 0 0 0 3.2-2.4A8 8 0 0 1 10 14M8 6v8"/></g></svg>',qn='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="8" height="18" x="3" y="3" rx="1"/><path d="M7 3v18m13.4-2.1c.2.5-.1 1.1-.6 1.3l-1.9.7c-.5.2-1.1-.1-1.3-.6L11.1 5.1c-.2-.5.1-1.1.6-1.3l1.9-.7c.5-.2 1.1.1 1.3.6Z"/></g></svg>',Qn='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M7 16c.5-2 1.5-7 4-7c2 0 2 3 4 3c2.5 0 4.5-5 5-7"/></g></svg>',jt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="12" cy="10" r="3"/><path d="M7 21v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2"/></g></svg>',Dt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 3.128a4 4 0 0 1 0 7.744M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/></g></svg>',Bt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M13.172 2a2 2 0 0 1 1.414.586l6.71 6.71a2.4 2.4 0 0 1 0 3.408l-4.592 4.592a2.4 2.4 0 0 1-3.408 0l-6.71-6.71A2 2 0 0 1 6 9.172V3a1 1 0 0 1 1-1zM2 7v6.172a2 2 0 0 0 .586 1.414l6.71 6.71a2.4 2.4 0 0 0 3.191.193"/><circle cx="10.5" cy="6.5" r=".5" fill="currentColor"/></g></svg>',eo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m16 18l6-6l-6-6M8 6l-6 6l6 6"/></svg>',st='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="12" x="3" y="8" rx="1"/><path d="M10 8V5c0-.6-.4-1-1-1H6a1 1 0 0 0-1 1v3m14 0V5c0-.6-.4-1-1-1h-3a1 1 0 0 0-1 1v3"/></g></svg>',to='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M14 14a2 2 0 0 0 2-2V8h-2"/><path d="M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z"/><path d="M8 14a2 2 0 0 0 2-2V8H8"/></g></svg>',io='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M10 22V7a1 1 0 0 0-1-1H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5a1 1 0 0 0-1-1H2"/><rect width="8" height="8" x="14" y="2" rx="1"/></g></svg>',Ht='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/></g></svg>',Lt='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 6v6l4 2m4-2v5m0 4h.01"/><path d="M21.25 8.2A10 10 0 1 0 16 21.16"/></g></svg>',no='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><path d="M2 10h20"/></g></svg>',oo='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M11.5 15H7a4 4 0 0 0-4 4v2m18.378-4.374a1 1 0 0 0-3.004-3.004l-4.01 4.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z"/><circle cx="10" cy="7" r="4"/></g></svg>',so='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2s4-2 4-2M9 9h.01M15 9h.01"/></g></svg>',ro='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><rect width="18" height="7" x="3" y="3" rx="1"/><rect width="9" height="7" x="3" y="14" rx="1"/><rect width="5" height="7" x="16" y="14" rx="1"/></g></svg>',ao='<svg role="img" class="ninja-icon" width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/></g></svg>',lo=i=>[{key:"light",label:i("COMMAND_BAR.COMMANDS.LIGHT_MODE"),icon:zn},{key:"dark",label:i("COMMAND_BAR.COMMANDS.DARK_MODE"),icon:Fn},{key:"auto",label:i("COMMAND_BAR.COMMANDS.SYSTEM_MODE"),icon:Yn}],co=i=>{Di.set(Hi.COLOR_SCHEME,i);const e=window.matchMedia("(prefers-color-scheme: dark)").matches;Ni(e)};function ho(){const{t:i}=ae(),e=m(()=>lo(i));return{goToAppearanceHotKeys:m(()=>{const n=e.value.map(o=>({id:o.key,title:o.label,parent:"appearance_settings",section:i("COMMAND_BAR.SECTIONS.APPEARANCE"),icon:o.icon,handler:()=>{co(o.key)}}));return[{id:"appearance_settings",title:i("COMMAND_BAR.COMMANDS.CHANGE_APPEARANCE"),section:i("COMMAND_BAR.SECTIONS.APPEARANCE"),icon:Kn,children:n.map(o=>o.id)},...n]})}}const j=qe.SNOOZE_OPTIONS,ue=i=>()=>le.emit(Zt,i),uo=[{id:"snooze_notification",title:"COMMAND_BAR.COMMANDS.SNOOZE_NOTIFICATION",icon:ie,children:Object.values(j)},{id:j.AN_HOUR_FROM_NOW,title:"COMMAND_BAR.COMMANDS.AN_HOUR_FROM_NOW",parent:"snooze_notification",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",icon:ie,handler:ue(j.AN_HOUR_FROM_NOW)},{id:j.UNTIL_TOMORROW,title:"COMMAND_BAR.COMMANDS.UNTIL_TOMORROW",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:ie,handler:ue(j.UNTIL_TOMORROW)},{id:j.UNTIL_NEXT_WEEK,title:"COMMAND_BAR.COMMANDS.UNTIL_NEXT_WEEK",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:ie,handler:ue(j.UNTIL_NEXT_WEEK)},{id:j.UNTIL_NEXT_MONTH,title:"COMMAND_BAR.COMMANDS.UNTIL_NEXT_MONTH",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:ie,handler:ue(j.UNTIL_NEXT_MONTH)},{id:j.UNTIL_CUSTOM_TIME,title:"COMMAND_BAR.COMMANDS.UNTIL_CUSTOM_TIME",section:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION",parent:"snooze_notification",icon:ie,handler:ue(j.UNTIL_CUSTOM_TIME)}];function po(){const{t:i}=ae(),e=lt(),t=o=>o.map(s=>({...s,title:i(s.title),section:s.section?i(s.section):void 0}));return{inboxHotKeys:m(()=>at(e.name)?t(uo):[])}}const X="COMMAND_BAR.SECTIONS.GENERAL",Z="COMMAND_BAR.SECTIONS.REPORTS",$="COMMAND_BAR.SECTIONS.SETTINGS",_o=[{id:"goto_my_inbox",title:"COMMAND_BAR.COMMANDS.GO_TO_MY_INBOX",section:X,icon:Je,routeName:"inbox_view"},{id:"goto_conversation_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_DASHBOARD",section:X,icon:Rt,routeName:"home"},{id:"goto_contacts_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CONTACTS_DASHBOARD",section:X,icon:Wn,routeName:"contacts_dashboard_index"},{id:"goto_captain",title:"COMMAND_BAR.COMMANDS.GO_TO_CAPTAIN",section:X,icon:kt,routeName:"captain_assistants_index",params:{navigationPath:"captain_assistants_overview_index"}},{id:"goto_calls_dashboard",title:"COMMAND_BAR.COMMANDS.GO_TO_CALLS_DASHBOARD",section:X,icon:Xn,routeName:"calls_dashboard_index"},{id:"goto_campaigns",title:"COMMAND_BAR.COMMANDS.GO_TO_CAMPAIGNS",section:X,icon:Jn,routeName:"campaigns_livechat_index"},{id:"goto_help_center",title:"COMMAND_BAR.COMMANDS.GO_TO_HELP_CENTER",section:X,icon:qn,routeName:"portals_index",params:{navigationPath:"portals_articles_index"}},{id:"open_reports_overview",title:"COMMAND_BAR.COMMANDS.GO_TO_REPORTS_OVERVIEW",section:Z,icon:Qn,routeName:"account_overview_reports"},{id:"open_conversation_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_CONVERSATION_REPORTS",section:Z,icon:Rt,routeName:"conversation_reports"},{id:"open_agent_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_AGENT_REPORTS",section:Z,icon:jt,routeName:"agent_reports_index"},{id:"open_label_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_LABEL_REPORTS",section:Z,icon:Bt,routeName:"label_reports_index"},{id:"open_inbox_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_INBOX_REPORTS",section:Z,icon:Je,routeName:"inbox_reports_index"},{id:"open_team_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_TEAM_REPORTS",section:Z,icon:Dt,routeName:"team_reports_index"},{id:"open_csat_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_CSAT_REPORTS",section:Z,icon:so,routeName:"csat_reports"},{id:"open_bot_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_BOT_REPORTS",section:Z,icon:kt,routeName:"bot_reports"},{id:"open_sla_reports",title:"COMMAND_BAR.COMMANDS.GO_TO_SLA_REPORTS",section:Z,icon:Lt,routeName:"sla_reports"},{id:"open_agent_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AGENTS",section:$,icon:jt,routeName:"agent_list"},{id:"open_team_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_TEAMS",section:$,icon:Dt,routeName:"settings_teams_list"},{id:"open_inbox_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_INBOXES",section:$,icon:Je,routeName:"settings_inbox_list"},{id:"open_template_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_TEMPLATES",section:$,icon:ro,routeName:"settings_templates"},{id:"open_label_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_LABELS",section:$,icon:Bt,routeName:"labels_list"},{id:"open_custom_attribute_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CUSTOM_ATTRIBUTES",section:$,icon:eo,routeName:"attributes_list"},{id:"open_macro_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_MACROS",section:$,icon:st,routeName:"macros_wrapper"},{id:"open_canned_response_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_CANNED_RESPONSES",section:$,icon:to,routeName:"canned_list"},{id:"open_sla_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_SLA",section:$,icon:Lt,routeName:"sla_list"},{id:"open_applications_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_APPLICATIONS",section:$,icon:io,routeName:"settings_applications"},{id:"open_data_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_DATA",section:$,icon:ao,routeName:"settings_data_imports"},{id:"open_audit_logs_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_AUDIT_LOGS",section:$,icon:Ht,routeName:"auditlogs_list"},{id:"open_billing_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_BILLING",section:$,icon:no,routeName:"billing_settings_index"},{id:"open_account_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_ACCOUNT",section:$,icon:Ht,routeName:"general_settings_index"},{id:"open_profile_settings",title:"COMMAND_BAR.COMMANDS.GO_TO_SETTINGS_PROFILE",section:$,icon:oo,routeName:"profile_settings_index"}];function vo(i=J(!1)){const{t:e}=ae(),t=Bi(),{checkPermissions:n,checkInstallationType:o,isFeatureFlagEnabled:s}=Ut(),r=pe("getCurrentAccountId"),a=h=>t.resolve({name:h.routeName,params:{accountId:r.value,...h.params}}),l=h=>{const{meta:d}=h;return!s(d==null?void 0:d.featureFlag)||!n(d==null?void 0:d.permissions)||!o(d==null?void 0:d.installationTypes)?!1:!i.value||Mi(h.name)};return{goToCommandHotKeys:m(()=>_o.flatMap(h=>{const d=a(h);return l(d)?{id:h.id,section:e(h.section),title:e(h.title),icon:h.icon,handler:()=>t.push(d)}:[]}))}}function fo(){return{bulkActionsHotKeys:m(()=>[])}}const go={id:"send_transcript",title:"COMMAND_BAR.COMMANDS.SEND_TRANSCRIPT",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:Rn,handler:()=>le.emit(Ei)},mo={id:"unmute_conversation",title:"COMMAND_BAR.COMMANDS.UNMUTE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:xn,handler:()=>le.emit(yi)},Ao={id:"mute_conversation",title:"COMMAND_BAR.COMMANDS.MUTE_CONVERSATION",section:"COMMAND_BAR.SECTIONS.CONVERSATION",icon:In,handler:()=>le.emit(Si)},Oo=(i,e)=>i.map(t=>({...t,title:e(t.title),section:e(t.section)})),Co=(i,e)=>[{label:i("CONVERSATION.PRIORITY.OPTIONS.NONE"),key:null,icon:Pn},{label:i("CONVERSATION.PRIORITY.OPTIONS.URGENT"),key:"urgent",icon:Dn},{label:i("CONVERSATION.PRIORITY.OPTIONS.HIGH"),key:"high",icon:Bn},{label:i("CONVERSATION.PRIORITY.OPTIONS.MEDIUM"),key:"medium",icon:Hn},{label:i("CONVERSATION.PRIORITY.OPTIONS.LOW"),key:"low",icon:Ln}].filter(t=>t.key!==e),wo=(i,e)=>e===Li.REPLY?[{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.REPLY_SUGGESTION"),key:"reply_suggestion",icon:ve}]:[{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.SUMMARIZE"),key:"summarize",icon:Zn}],No=i=>[{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.CONFIDENT"),key:"confident",icon:ve},{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.FIX_SPELLING_GRAMMAR"),key:"fix_spelling_grammar",icon:Vn},{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.PROFESSIONAL"),key:"professional",icon:Un},{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.CASUAL"),key:"casual",icon:Gn},{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.MAKE_FRIENDLY"),key:"friendly",icon:ve},{label:i("INTEGRATION_SETTINGS.OPEN_AI.OPTIONS.STRAIGHTFORWARD"),key:"straightforward",icon:ve}];function Mo(){const{t:i}=ae(),e=rt(),t=lt(),{activeLabels:n,inactiveLabels:o,addLabelToConversation:s,removeLabelFromConversation:r}=bi(),{captainTasksEnabled:a}=Ti(),l=pe("getSelectedChat"),c=pe("draftMessages/getReplyEditorMode"),h=pe("draftMessages/get"),d=m(()=>{var y;return(y=l.value)==null?void 0:y.id}),u=m(()=>`draft-${d.value}-${c.value}`),p=m(()=>h.value(u.value)),_=y=>{e.dispatch("assignPriority",{conversationId:l.value.id,priority:y.priority.key})},f=m(()=>{var y;return Co(i,(y=l.value)==null?void 0:y.priority)}),I=m(()=>{const y=f.value.map(C=>({id:`priority-${C.key}`,title:C.label,parent:"assign_priority",section:i("COMMAND_BAR.SECTIONS.CHANGE_PRIORITY"),priority:C,icon:C.icon,handler:_}));return[{id:"assign_priority",title:i("COMMAND_BAR.COMMANDS.ASSIGN_PRIORITY"),section:i("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:jn,children:y.map(C=>C.id)},...y]}),U=m(()=>[...o.value.map(C=>({id:C.title,title:`#${C.title}`,parent:"add_a_label_to_the_conversation",section:i("COMMAND_BAR.SECTIONS.ADD_LABEL"),icon:It,handler:x=>s({title:x.id})})),{id:"add_a_label_to_the_conversation",title:i("COMMAND_BAR.COMMANDS.ADD_LABELS_TO_CONVERSATION"),section:i("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:It,children:o.value.map(C=>C.title)}]),G=m(()=>[...n.value.map(C=>({id:C.title,title:`#${C.title}`,parent:"remove_a_label_to_the_conversation",section:i("COMMAND_BAR.SECTIONS.REMOVE_LABEL"),icon:xt,handler:x=>r(x.id)})),{id:"remove_a_label_to_the_conversation",title:i("COMMAND_BAR.COMMANDS.REMOVE_LABEL_FROM_CONVERSATION"),section:i("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:xt,children:n.value.map(C=>C.title)}]),Ne=m(()=>n.value.length?[...U.value,...G.value]:U.value),V=m(()=>Oo([l.value.muted?mo:Ao,go],i)),D=m(()=>{const C=(p.value?No(i):wo(i,c.value)).map(x=>({id:`ai-assist-${x.key}`,title:x.label,parent:"ai_assist",section:i("COMMAND_BAR.SECTIONS.AI_ASSIST"),priority:x,icon:x.icon,handler:()=>le.emit($i,x.key)}));return[{id:"ai_assist",title:i("COMMAND_BAR.COMMANDS.AI_ASSIST"),section:i("COMMAND_BAR.SECTIONS.AI_ASSIST"),icon:ve,children:C.map(x=>x.id)},...C]}),ke=m(()=>Gt(t.name)||at(t.name)),je=m(()=>{const y=[...V.value,...Ne.value,...I.value];return a.value?[...y,...D.value]:y});return{conversationHotKeys:m(()=>ke.value?je.value:[])}}function yo(){const{t:i}=ae(),e=rt(),t=lt(),{orderedMacros:n}=Ii(),{execute:o,submitPendingAttributes:s,dismissPendingAttributes:r}=xi(),{isFeatureFlagEnabled:a}=Ut(),l=pe("getSelectedChat"),c=J(null),h=m(()=>a(Pi.MACROS)&&(Gt(t.name)||at(t.name)));return Pt(h,u=>{u&&!n.value.length&&e.dispatch("macros/get")},{immediate:!0}),{macroHotKeys:m(()=>{if(!h.value||!n.value.length)return[];const u=n.value.map(p=>({id:`macro-${p.id}`,title:p.name,parent:"execute_a_macro",section:i("COMMAND_BAR.SECTIONS.EXECUTE_MACRO"),icon:st,handler:()=>{c.value=o(p,l.value.id)}}));return[{id:"execute_a_macro",title:i("COMMAND_BAR.COMMANDS.EXECUTE_A_MACRO"),section:i("COMMAND_BAR.SECTIONS.CONVERSATION"),icon:st,children:u.map(p=>p.id)},...u]}),pendingAttributes:c,submitPendingAttributes:s,dismissPendingAttributes:r}}const So=["placeholder"],Eo="dynamic_snooze_",ls={__name:"commandbar",props:{isPaywalled:{type:Boolean,default:!1}},setup(i){const e=i,t=rt(),{t:n,tm:o}=ae(),{resolvedLocale:s}=Ri(),r=J(null),a=J(null),l=J(null),{goToAppearanceHotKeys:c}=ho(),{inboxHotKeys:h}=po(),{goToCommandHotKeys:d}=vo(_i(e,"isPaywalled")),{bulkActionsHotKeys:u}=fo(),{conversationHotKeys:p}=Mo(),{macroHotKeys:_,pendingAttributes:f,submitPendingAttributes:I,dismissPendingAttributes:U}=yo();Pt(f,v=>{var T;v&&((T=a.value)==null||T.open(v.missing,v.customAttributes))});const G=["snooze_notification"],Ne=qe.SNOOZE_OPTIONS.UNTIL_CUSTOM_TIME,V=J([]),D=J(null),ke=m(()=>G.includes(D.value)?n("COMMAND_BAR.SNOOZE_PLACEHOLDER"):n("COMMAND_BAR.SEARCH_PLACEHOLDER")),je=new Set(Object.values(qe.SNOOZE_OPTIONS)),De=m(()=>{if(e.isPaywalled)return[...c.value,...d.value];const v=[...V.value,...h.value,...d.value,...c.value,...u.value,...p.value,..._.value];return V.value.length?v.filter(T=>!je.has(T.id)||!G.includes(T.parent)):v}),y=()=>{r.value.data=De.value},C={snooze_notification:Zt},x={snooze_notification:"COMMAND_BAR.SECTIONS.SNOOZE_NOTIFICATION"},ai=m(()=>{const v=o("SNOOZE_PARSER");return!v||typeof v!="object"?{}:JSON.parse(JSON.stringify(v))}),li=(v,T)=>{const H=ji(v,new Date,{translations:ai.value,locale:s.value});if(!H.length)return[];const R=C[T],L=n(x[T]);return H.map((P,pi)=>({id:`${Eo}${pi}`,title:P.label!==P.formattedDate?`${P.label} - ${P.formattedDate}`:P.formattedDate,parent:T,section:L,icon:kn,keywords:v,handler:()=>{le.emit(R,P.resolve()),pt(Ui.NLP_SNOOZE_APPLIED,{label:P.label})}}))},dt=()=>{D.value=null,V.value=[]},ci=v=>{if(!v||typeof v.open!="function"||typeof v.close!="function")return;const T=v.open.bind(v),H=v.close.bind(v);v.open=(...R)=>{const[L={}]=R;return D.value=L.parent||null,V.value=[],T(...R)},v.close=(...R)=>(dt(),H(...R))},hi=v=>{const{detail:{action:{title:T=null,section:H=null,id:R=null,children:L=null}={}}={}}=v;l.value=R===Ne?R:null,Array.isArray(L)&&L.length&&(D.value=R),pt(Zi.COMMAND_BAR,{section:H,action:T}),y()},di=v=>{const{detail:{search:T="",actions:H=[]}={}}=v,R=T.trim();if(H.length>0){const L=[...new Set(H.map(P=>P.parent).filter(Boolean))];L.length===1?D.value=L[0]:D.value=null}if(!R||!G.includes(D.value||"")){V.value=[];return}V.value=li(R,D.value)},ui=()=>{l.value!==Ne&&t.dispatch("setContextMenuChatId",null),dt()};return vi(()=>{r.value&&(r.value.data=De.value)}),fi(()=>{y(),ci(r.value)}),(v,T)=>(gi(),mi(Ci,null,[Ai("ninja-keys",{ref_key:"ninjakeys",ref:r,noAutoLoadMdIcons:"",hideBreadcrumbs:"",placeholder:ke.value,onChange:di,onSelected:hi,onClosed:ui},null,40,So),Oi(ki,{ref_key:"resolveAttributesModalRef",ref:a,onSubmit:ut(I),onClose:ut(U)},null,8,["onSubmit","onClose"])],64))}};export{ls as default};
//# sourceMappingURL=commandbar-Ctg1I936.js.map
