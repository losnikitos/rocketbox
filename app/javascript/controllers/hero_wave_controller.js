import { Controller } from "@hotwired/stimulus"
import * as THREE from "three"

// Port of Stripe dashboard login "HeroWave" (Three.js folded mesh + glow shader).
// Config/uniforms from their createLoginWaveConfig; shaders simplified (unused shaping trimmed).

const VERT = /* glsl */ `
uniform float u_time;
uniform float u_speed;
uniform vec2 u_resolution;
uniform float u_twistFrequencyX;
uniform float u_twistFrequencyY;
uniform float u_twistFrequencyZ;
uniform float u_twistPowerX;
uniform float u_twistPowerY;
uniform float u_twistPowerZ;
uniform float u_displaceFrequencyX;
uniform float u_displaceFrequencyZ;
uniform float u_displaceAmount;

varying float v_time;
varying vec2 v_uv;
varying vec3 v_position;
varying vec4 v_clipPosition;
varying vec2 v_resolution;

// ponytail: classic hash instead of Stripe xxhash (needs WebGL2 uint bitcasts)
vec2 hash(vec2 x) {
  float k = 6.283185307 * fract(sin(dot(x, vec2(127.1, 311.7))) * 43758.5453);
  return vec2(cos(k), sin(k));
}

float simplexNoise(in vec2 p) {
  const float K1 = 0.366025404;
  const float K2 = 0.211324865;
  vec2 i = floor(p + (p.x + p.y) * K1);
  vec2 a = p - i + (i.x + i.y) * K2;
  float m = step(a.y, a.x);
  vec2 o = vec2(m, 1.0 - m);
  vec2 b = a - o + K2;
  vec2 c = a - 1.0 + 2.0 * K2;
  vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
  vec3 n = h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
  return dot(n, vec3(32.99));
}

float expStep(float x, float n) {
  return exp2(-exp2(n) * pow(x, n));
}

float mapLinear(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

mat4 rotationMatrix(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;
  return mat4(
    oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s, 0.0,
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0,
    0.0, 0.0, 0.0, 1.0
  );
}

vec3 displace(vec2 uv, vec3 position, float time, float frequencyX, float frequencyY, float amount) {
  float noise = simplexNoise(vec2(position.x * frequencyX + time, position.z * frequencyY + time));
  position.y += amount * noise;
  return position;
}

void main() {
  v_time = u_time;
  v_uv = uv;
  v_resolution = u_resolution;

  mat4 rotationA = rotationMatrix(vec3(0.5, 0.0, 0.5), u_twistFrequencyY * expStep(v_uv.x, u_twistPowerY));
  mat4 rotationB = rotationMatrix(vec3(0.0, 0.5, 0.5), u_twistFrequencyX * expStep(v_uv.y, u_twistPowerX));
  mat4 rotationC = rotationMatrix(vec3(0.5, 0.0, 0.5), u_twistFrequencyZ * expStep(v_uv.y, u_twistPowerZ));

  vec3 displacedPosition = displace(uv, position.xyz, u_time * u_speed, u_displaceFrequencyX, u_displaceFrequencyZ, u_displaceAmount);

  v_position = displacedPosition;
  v_position = (vec4(v_position, 1.0) * rotationA).xyz;
  v_position = (vec4(v_position, 1.0) * rotationB).xyz;
  v_position = (vec4(v_position, 1.0) * rotationC).xyz;

  v_clipPosition = projectionMatrix * modelViewMatrix * vec4(v_position, 1.0);
  gl_Position = v_clipPosition;
}
`

const FRAG = /* glsl */ `
precision highp float;

varying float v_time;
varying vec2 v_uv;
varying vec3 v_position;
varying vec4 v_clipPosition;
varying vec2 v_resolution;

uniform sampler2D u_paletteTexture;
uniform float u_colorSaturation;
uniform float u_colorContrast;
uniform float u_colorHueShift;
uniform float u_glowAmount;
uniform float u_glowPower;
uniform float u_glowRamp;
uniform vec3 u_clearColor;

vec2 hash(vec2 x) {
  float k = 6.283185307 * fract(sin(dot(x, vec2(127.1, 311.7))) * 43758.5453);
  return vec2(cos(k), sin(k));
}

float simplexNoise(in vec2 p) {
  const float K1 = 0.366025404;
  const float K2 = 0.211324865;
  vec2 i = floor(p + (p.x + p.y) * K1);
  vec2 a = p - i + (i.x + i.y) * K2;
  float m = step(a.y, a.x);
  vec2 o = vec2(m, 1.0 - m);
  vec2 b = a - o + K2;
  vec2 c = a - 1.0 + 2.0 * K2;
  vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
  vec3 n = h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
  return dot(n, vec3(32.99));
}

float parabola(float x, float k) {
  return pow(4.0 * x * (1.0 - x), k);
}

float mapLinear(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

vec3 contrast(in vec3 v, in float a) {
  return (v - 0.5) * a + 0.5;
}

vec3 desaturate(vec3 color, float factor) {
  vec3 lum = vec3(0.299, 0.587, 0.114);
  vec3 gray = vec3(dot(lum, color));
  return mix(color, gray, factor);
}

vec3 hueShift(vec3 color, float shift) {
  vec3 gray = vec3(0.57735);
  vec3 projection = gray * dot(gray, color);
  vec3 U = color - projection;
  vec3 V = cross(gray, U);
  return U * cos(shift) + V * sin(shift) + projection;
}

vec3 surfaceColor(vec2 uv, float pdy) {
  vec3 color = texture2D(u_paletteTexture, vec2(uv.x, uv.y)).rgb;
  float p = 1.0 - parabola(uv.x, 3.0);
  float n0 = simplexNoise(vec2(v_uv.x * 0.1, v_uv.y * 0.5));
  float n1 = simplexNoise(vec2(v_uv.x * (600.0 + (300.0 * n0)), v_uv.y * 4.0 * n0));
  n1 = mapLinear(n1, -1.0, 1.0, 0.0, 1.0);
  color += (n1 * 0.2 * (1.0 - color.b * 0.9) * pdy * p);
  return color;
}

void main() {
  vec2 dy = dFdy(v_uv);
  float pdy = dy.y * v_resolution.y * u_glowAmount;
  pdy = mapLinear(pdy, -1.0, 1.0, 0.0, 1.0);
  pdy = clamp(pdy, 0.0, 1.0);
  pdy = pow(pdy, u_glowPower);
  pdy = smoothstep(0.0, u_glowRamp, pdy);
  pdy = clamp(pdy, 0.0, 1.0);

  vec4 color = vec4(surfaceColor(v_uv, pdy), 1.0);
  color.rgb = contrast(color.rgb, u_colorContrast);
  color.rgb = desaturate(color.rgb, 1.0 - u_colorSaturation);
  color.rgb = hueShift(color.rgb, u_colorHueShift);
  color.rgb += (1.0 - pdy) * 0.25;
  gl_FragColor = clamp(color, 0.0, 1.0);
}
`

// Stripe HeroWavePostProcessingMaterial — angular blur + grain softens the ribbon edges
const POST_VERT = /* glsl */ `
varying vec2 v_uv;

void main() {
  v_uv = uv;
  gl_Position = vec4(position, 1.0);
}
`

const POST_FRAG = /* glsl */ `
precision highp float;

uniform sampler2D u_scene;
uniform float u_blurAmount;
uniform float u_grainAmount;
varying vec2 v_uv;

float random(in vec2 st) {
  return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 grain(vec3 color, float amount) {
  float grid_position = random(gl_FragCoord.xy * 0.01);
  vec3 dither_shift_RGB = vec3(4.0 / 255.0);
  dither_shift_RGB = mix(amount * dither_shift_RGB, -amount * dither_shift_RGB, grid_position);
  return color + dither_shift_RGB;
}

vec4 blurAngular(sampler2D tex, vec2 uv, float angle) {
  const int samples = 6;
  vec4 total = vec4(0.0);
  vec2 coord = uv - 0.5;
  float dist = 1.0 / float(samples);
  vec2 dir = vec2(cos(angle * dist), sin(angle * dist));
  mat2 rot = mat2(dir.x, dir.y, -dir.y, dir.x);

  for (int i = 0; i < samples; i++) {
    total += texture2D(tex, coord + 0.5);
    coord *= rot;
  }
  return total * dist;
}

void main() {
  vec4 sceneColor = texture2D(u_scene, v_uv);
  vec4 blurColor = blurAngular(u_scene, v_uv, u_blurAmount);
  float blurPower = smoothstep(0.0, 0.7, v_uv.y) - smoothstep(0.2, 1.0, v_uv.y);
  vec4 finalColor = mix(blurColor, sceneColor, blurPower);
  finalColor.rgb = grain(finalColor.rgb, u_grainAmount);
  gl_FragColor = vec4(min(finalColor.rgb, 1.0), finalColor.a);
}
`

function mapLinear(value, min1, max1, min2, max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1)
}

function parabola(x, n) {
  return Math.pow(4 * x * (1 - x), n)
}

function foldedGeometry(width = 400, height = 400, segX = 128, segY = 256) {
  const geo = new THREE.PlaneGeometry(width, height, segX, segY)
  const pos = geo.attributes.position
  const uv = geo.attributes.uv
  const fold = 16 // Stripe HeroWaveGeometry.folded
  const depth = 4
  const xAxis = new THREE.Vector3(1, 0, 0)
  const yAxis = new THREE.Vector3(0, 1, 0)
  const v = new THREE.Vector3()
  const u = new THREE.Vector2()

  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i)
    u.fromBufferAttribute(uv, i)
    const p = parabola(u.y, 9.5)
    const amp = depth - 2 * p
    if (v.x < -fold) {
      v.z += amp
    } else if (v.x < fold) {
      v.z = Math.cos(mapLinear(v.x, -fold, fold, 0, Math.PI)) * amp
      v.x = Math.cos(mapLinear(v.x, -fold, fold, -Math.PI / 2, Math.PI / 2)) * amp - fold
    } else {
      v.z -= amp
      v.x = -v.x
    }
    v.x += width / 4
    v.applyAxisAngle(xAxis, -Math.PI / 2)
    v.applyAxisAngle(yAxis, -Math.PI / 2)
    pos.setXYZ(i, v.x, v.y, v.z)
  }
  pos.needsUpdate = true
  geo.computeVertexNormals()
  return geo
}

// Exact Stripe createLoginWaveConfig + breakpoints from dashboard login
// small ≤639 | medium 640–1263 | wide ≥1264
function createLoginWaveConfig({ positionX, positionY, rotationZ, referenceHeight, offsetX }) {
  return {
    material: {
      speed: 4e-5,
      timeOffset: 17500,
      colorContrast: 1,
      colorSaturation: 1,
      colorHueShift: -0.00159265358979299,
      displaceFrequencyX: 0.005831,
      displaceFrequencyZ: 0.016001,
      displaceAmount: -7.821,
      positionX,
      positionY,
      positionZ: -11.1,
      rotationX: -0.449592653589793,
      rotationY: -0.117592653589793,
      rotationZ,
      scaleX: 9,
      scaleY: 8,
      scaleZ: 5,
      twistFrequencyX: -0.65,
      twistFrequencyY: 0.41,
      twistFrequencyZ: -0.58,
      twistPowerX: 3.63,
      twistPowerY: 0.7,
      twistPowerZ: 3.95,
      glowRamp: 0.834,
      glowAmount: 1.98,
      glowPower: 0.806
    },
    cam: {
      x: 100,
      y: 0,
      z: 5000,
      referenceHeight,
      offsetX,
      offsetYFraction: -0.25
    }
  }
}

const WIDE = createLoginWaveConfig({
  positionX: 380,
  positionY: -301.7,
  rotationZ: 1.87440734641021,
  referenceHeight: 2500,
  offsetX: 250
})
const MEDIUM = createLoginWaveConfig({
  positionX: 475,
  positionY: -301.7,
  rotationZ: 1.72,
  referenceHeight: 1250,
  offsetX: 0
})
const SMALL = createLoginWaveConfig({
  positionX: 260,
  positionY: -370,
  rotationZ: 1.52,
  referenceHeight: 1250,
  offsetX: 0
})

const POST = {
  blurAmount: 0.02,
  grainAmount: 1.1
}

function stripeConfig() {
  if (window.matchMedia("(max-width: 639px)").matches) return SMALL
  if (window.matchMedia("(min-width: 640px) and (max-width: 1263px)").matches) return MEDIUM
  return WIDE
}

export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.disposed = false
    this.#boot()
  }

  disconnect() {
    this.disposed = true
    this.#teardown()
  }

  async #boot() {
    const canvas = this.canvasTarget
    const clear = new THREE.Color(0xffffff)
    this.config = stripeConfig()
    const m = this.config.material
    const cam = this.config.cam

    let renderer
    try {
      // Stripe light theme: antialias false, alpha false
      renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: false,
        alpha: false,
        powerPreference: "high-performance"
      })
    } catch {
      return
    }

    this.renderer = renderer
    this.dpr = Math.min(window.devicePixelRatio || 1, 2)
    renderer.setPixelRatio(this.dpr)
    renderer.setClearColor(clear, 1)
    renderer.outputColorSpace = THREE.SRGBColorSpace

    this.scene = new THREE.Scene()
    this.camera = new THREE.OrthographicCamera(0, 0, 0, 0, 1, 10000)
    this.camera.position.set(cam.x, cam.y, cam.z)
    this.camera.lookAt(0, 0, 0)

    const loader = new THREE.TextureLoader()
    const palette = await new Promise((resolve, reject) => {
      loader.load("/hero-wave-palette.png", resolve, undefined, reject)
    }).catch(() => null)
    if (!palette || this.disposed) {
      this.#teardown()
      return
    }
    palette.wrapS = palette.wrapT = THREE.RepeatWrapping
    palette.colorSpace = THREE.SRGBColorSpace

    const uniforms = {
      u_time: { value: m.timeOffset },
      u_speed: { value: m.speed },
      u_resolution: { value: new THREE.Vector2(1, 1) },
      u_paletteTexture: { value: palette },
      u_colorContrast: { value: m.colorContrast },
      u_colorSaturation: { value: m.colorSaturation },
      u_colorHueShift: { value: m.colorHueShift },
      u_displaceFrequencyX: { value: m.displaceFrequencyX },
      u_displaceFrequencyZ: { value: m.displaceFrequencyZ },
      u_displaceAmount: { value: m.displaceAmount },
      u_twistFrequencyX: { value: m.twistFrequencyX },
      u_twistFrequencyY: { value: m.twistFrequencyY },
      u_twistFrequencyZ: { value: m.twistFrequencyZ },
      u_twistPowerX: { value: m.twistPowerX },
      u_twistPowerY: { value: m.twistPowerY },
      u_twistPowerZ: { value: m.twistPowerZ },
      u_glowAmount: { value: m.glowAmount },
      u_glowPower: { value: m.glowPower },
      u_glowRamp: { value: m.glowRamp },
      u_clearColor: { value: clear.clone() }
    }

    this.uniforms = uniforms
    const material = new THREE.ShaderMaterial({
      uniforms,
      vertexShader: VERT,
      fragmentShader: FRAG,
      side: THREE.DoubleSide,
      depthTest: true,
      depthWrite: true,
      transparent: false,
      extensions: { derivatives: true }
    })

    const mesh = new THREE.Mesh(foldedGeometry(), material)
    mesh.position.set(m.positionX, m.positionY, m.positionZ)
    mesh.rotation.set(m.rotationX, m.rotationY, m.rotationZ)
    mesh.scale.set(m.scaleX, m.scaleY, m.scaleZ)
    this.mesh = mesh
    this.scene.add(mesh)

    // Stripe only enables post on light + non-mobile
    const isMobile = window.matchMedia("(pointer: coarse) and (hover: none)").matches
    if (!isMobile) this.#initPost()

    this.#resize()
    this.ro = new ResizeObserver(() => this.#resize())
    this.ro.observe(this.element)
    this.mq = [
      window.matchMedia("(max-width: 639px)"),
      window.matchMedia("(min-width: 640px) and (max-width: 1263px)"),
      window.matchMedia("(min-width: 1264px)")
    ]
    this.onBreakpoint = () => this.#applyConfig(stripeConfig())
    this.mq.forEach((q) => q.addEventListener("change", this.onBreakpoint))
    this.raf = requestAnimationFrame((t) => this.#frame(t))
  }

  #applyConfig(config) {
    this.config = config
    const m = config.material
    if (!this.mesh || !this.uniforms) return
    this.mesh.position.set(m.positionX, m.positionY, m.positionZ)
    this.mesh.rotation.set(m.rotationX, m.rotationY, m.rotationZ)
    this.mesh.scale.set(m.scaleX, m.scaleY, m.scaleZ)
    Object.entries({
      u_colorContrast: m.colorContrast,
      u_colorSaturation: m.colorSaturation,
      u_colorHueShift: m.colorHueShift,
      u_displaceFrequencyX: m.displaceFrequencyX,
      u_displaceFrequencyZ: m.displaceFrequencyZ,
      u_displaceAmount: m.displaceAmount,
      u_twistFrequencyX: m.twistFrequencyX,
      u_twistFrequencyY: m.twistFrequencyY,
      u_twistFrequencyZ: m.twistFrequencyZ,
      u_twistPowerX: m.twistPowerX,
      u_twistPowerY: m.twistPowerY,
      u_twistPowerZ: m.twistPowerZ,
      u_glowAmount: m.glowAmount,
      u_glowPower: m.glowPower,
      u_glowRamp: m.glowRamp
    }).forEach(([k, v]) => { this.uniforms[k].value = v })
    this.#resize()
  }

  #initPost() {
    const { width, height } = this.element.getBoundingClientRect()
    const resW = Math.max(1, Math.floor(width * this.dpr))
    const resH = Math.max(1, Math.floor(height * this.dpr))

    this.sceneTarget = new THREE.WebGLRenderTarget(resW, resH)
    this.postUniforms = {
      u_scene: { value: this.sceneTarget.texture },
      u_blurAmount: { value: POST.blurAmount },
      u_grainAmount: { value: POST.grainAmount }
    }
    const postMaterial = new THREE.ShaderMaterial({
      uniforms: this.postUniforms,
      vertexShader: POST_VERT,
      fragmentShader: POST_FRAG,
      depthTest: false,
      depthWrite: false
    })
    this.postMaterial = postMaterial
    this.postScene = new THREE.Scene()
    this.postScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), postMaterial))
    this.postCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1)
  }

  #resize() {
    if (!this.renderer || !this.config) return
    const { width, height } = this.element.getBoundingClientRect()
    if (width < 1 || height < 1) return
    this.renderer.setSize(width, height, false)
    this.camera.left = -width / 2
    this.camera.right = width / 2
    this.camera.top = height / 2
    this.camera.bottom = -height / 2
    this.camera.updateProjectionMatrix()
    const cam = this.config.cam
    // Stripe applyCameraOffset
    this.camera.position.x = cam.x - cam.offsetX
    this.camera.position.y =
      cam.y + cam.referenceHeight * (0.5 + cam.offsetYFraction) - height / 2
    const resW = width * this.dpr
    const resH = height * this.dpr
    this.uniforms.u_resolution.value.set(resW, resH)
    this.sceneTarget?.setSize(resW, resH)
  }

  #frame(t) {
    if (this.disposed) return
    this.raf = requestAnimationFrame((nt) => this.#frame(nt))
    // Stripe renders every other frame
    this._skip = !this._skip
    if (this._skip) return

    if (this.start == null) this.start = t
    this.uniforms.u_time.value = this.config.material.timeOffset + (t - this.start)

    if (this.sceneTarget) {
      this.renderer.setRenderTarget(this.sceneTarget)
      this.renderer.render(this.scene, this.camera)
      this.renderer.setRenderTarget(null)
      this.renderer.render(this.postScene, this.postCamera)
    } else {
      this.renderer.render(this.scene, this.camera)
    }
  }

  #teardown() {
    if (this.raf) cancelAnimationFrame(this.raf)
    this.ro?.disconnect()
    this.mq?.forEach((q) => q.removeEventListener("change", this.onBreakpoint))
    this.mesh?.geometry.dispose()
    this.mesh?.material.dispose()
    this.postMaterial?.dispose()
    this.postScene?.traverse((obj) => {
      if (obj.geometry) obj.geometry.dispose()
    })
    this.sceneTarget?.dispose()
    this.uniforms?.u_paletteTexture.value?.dispose()
    this.renderer?.dispose()
    this.renderer = null
  }
}
