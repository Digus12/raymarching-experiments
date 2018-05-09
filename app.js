const glslify = require('glslify')

import createShader from 'gl-shader'
import createTexture from 'gl-texture2d'
import createFBO from 'gl-fbo'

import ndarray from 'ndarray'
import fit from 'canvas-fit'
import TWEEN from 'tween.js'
import makeContext from 'gl-context'
import { rot4 } from './utils'
import drawTriangle from 'a-big-triangle'

import defined from 'defined'
import { vec3, mat4 } from 'gl-matrix'

import Octavian from 'octavian'
import createSwell from './audio/swell'

const dpr = Math.min(2, defined(window.devicePixelRatio, 1))

// const TWO_PI = 2 * Math.PI
const PHI = (1 + Math.sqrt(5)) / 2

const MANDELBOX = false
const BLOOM = true
const BLOOM_WET = 0
const BLOOM_PASSES = 0
const BLOOM_MIN_BRIGHTNESS = 0.9

// Initialize shell
export default class App {
  constructor (options = {}) {
    let canvas = document.createElement('canvas')
    document.body.appendChild(canvas)
    canvas.style.display = 'none'

    let gl = makeContext(canvas, { preserveDrawingBuffer: true })

    // enable extensions
    var ext = gl.getExtension('OES_standard_derivatives')
    if (!ext) {
      throw new Error('derivatives not supported')
    }

    this.LOOKAT = true

    this.presets = {}
    const thingy = {
      offset: {
        x: 1,
        y: 0.876,
        z: 2.544
      },
      d: 5,
      scale: 1.28,
      rot2angle: [0.264, 0.86, 0.671],
      cameraAngles: [-0.621, -0.469, -0.298]
    }
    this.presets.thingy = thingy

    const nova = {
      offset: {
        x: 1.993,
        y: 0.552,
        z: -1.205
      },
      d: 5,
      scale: 1.01,
      rot2angle: [0.264, 0.313, 5.225],
      cameraAngles: [-0.621, -0.469, -0.298]
    }
    this.presets.nova = nova

    const jackOLatern = {
      offset: {
        x: 1.038,
        y: -1.195,
        z: 0.524
      },
      d: 5,
      scale: 1.52,
      rot2angle: [0.264, 0.313, 5.225],
      cameraAngles: [-0.621, -0.469, -0.298]
    }
    this.presets.jackOLatern = jackOLatern

    const fractalGem1 = {
      offset: {
        x: 1.441,
        y: 0.89,
        z: 0.228
      },
      d: 5,
      scale: 1.13,
      rot2angle: [0, 0, 0],
      cameraAngles: [-0.621, -0.469, -0.298]
    }
    this.presets.fractalGem1 = fractalGem1

    this.presets.tiledSphere = {
      offset: {
        x: 1.111,
        y: 0.339,
        z: 0.362
      },
      d: 5,
      scale: 0.94,
      rot2angle: [0.583, 0.945, 0],
      cameraAngles: [-0.621, -0.469, -0.298]
    }
    this.presets.something = {
      offset: {
        x: 0.815,
        y: 0.449,
        z: 0.641
      },
      d: 5,
      scale: 1.79,
      rot2angle: [0.136, 0, 0],
      cameraAngles: [-0.621, -0.469, -0.298]
    }

    this.presets.tatted = {
      offset: {
        x: 0.326,
        y: 2.61,
        z: 0.716
      },
      d: 5,
      scale: 1.28,
      rot2angle: [0.111, 0.385, 0.481],
      cameraAngles: [-0.621, -0.469, -0.298]
    }

    this.presets.dodecSierpinski = {
      offset: {
        x: 1,
        y: 1,
        z: 1
      },
      d: 5,
      scale: PHI * PHI,
      rot2angle: [0, 0, 0],
      cameraAngles: [-0.621, -0.469, -0.298]
    }

    this.presets.mandelbox2 = {
      offset: {
        x: 0,
        y: 0,
        z: 0
      },
      d: 5,
      scale: 2.11,
      rot2angle: [1.703, 0, 0],
      cameraAngles: [-0.203, -0.009, 0]
    }
    this.presets.fractalGem2 = {
      offset: {
        x: 0.228,
        y: 0,
        z: 0
      },
      d: 5,
      scale: 1.13,
      rot2angle: [0.138, 0, 0],
      cameraAngles: [-0.203, -0.009, 0]
    }
    this.presets.kaleidoGem = {
      offset: {
        x: 0.339,
        y: 0.635,
        z: 0.017
      },
      d: 5,
      scale: 2.02,
      rot2angle: [0.301, 0, 0],
      cameraAngles: [-0.203, -0.009, 0]
    }

    this.presets.blend1 = {
      offset: {
        x: 1.441,
        y: 0.457,
        z: 0.4
      },
      d: 5,
      scale: 1.61,
      rot2angle: [0.301, 0, 0],
      cameraAngles: [-0.203, -0.009, 0]
    }

    this.presets.blend2 = {
      offset: {
        x: 0.499,
        y: 0.029,
        z: 0.21
      },
      d: 5,
      scale: 2.52,
      rot2angle: [0.301, 0, 0],
      cameraAngles: [-0.203, -0.009, 0]
    }

    const preset = this.presets.blend1
    const preset2 = this.presets.blend2
    preset.cameraAngles = [-0.035, 0, 0]

    this.d = preset.d
    const dist = 1
    this.cameraRo = vec3.fromValues(0, 0, dist)
    this.offsetC = [0.339, -0.592, 0.228, 0.008]

    // Ray Marching Parameters
    this.epsilon = preset.epsilon || 0.00001

    // Fractal parameters
    this.offset = (preset.offset)
      ? vec3.fromValues(preset.offset.x, preset.offset.y, preset.offset.z)
      : vec3.fromValues(0, 0, 0)
    this.scale = preset.scale
    this.rot2angle = preset.rot2angle || [0, 0, 0]
    this.cameraAngles = preset.cameraAngles || [0, 0, 0]

    this.offset2 = (preset2.offset)
      ? vec3.fromValues(preset2.offset.x, preset2.offset.y, preset2.offset.z)
      : vec3.fromValues(0, 0, 0)
    this.scale2 = preset2.scale

    this.angle1C = 0.136
    this.angle2C = 0.705
    this.angle3C = 0.143

    this.setupAnimation(preset)

    this.glInit(gl)

    // Audio
    this.audioFFT = 512
    this.audioTexArray = new Uint8Array(1 * this.audioFFT)
    this.audioNday = ndarray(this.audioTexArray, [this.audioFFT, 1])
    this.audioTex = createTexture(gl, this.audioNday)
    this.pulseGoal = 0

    // Capturing state
    this.capturing = defined(options.capturing, false)

    let tMatCapImg = new Image()
    tMatCapImg.src = './env.jpg'

    let tMatCapImgLoaded = new Promise((resolve, reject) => {
      tMatCapImg.onload = () => {
        this.tMatCap = createTexture(gl, tMatCapImg)
        resolve()
      }
    })

    this.loaded = Promise.all([tMatCapImgLoaded])
      .then(() => {
        // this.setupAudio()
      })

    // Scene Rendering
    this.sceneRender = defined(options.sceneRender, this.defaultSceneRender)

    Object.assign(this, {
      canvas,
      gl
    })
  }

  getDimensions () {
    return [dpr * window.innerWidth, dpr * window.innerHeight]
  }

  setupFBOs (gl) {
    let dim = this.getDimensions()
    this.state = [
      createFBO(gl, dim, { depth: false }),
      createFBO(gl, dim, { depth: false }),
      createFBO(gl, dim, { depth: false }) ]

    this.state[0].color.magFilter = gl.LINEAR
    this.state[0].color.minFilter = gl.LINEAR
    this.state[1].color.magFilter = gl.LINEAR
    this.state[1].color.minFilter = gl.LINEAR
    this.state[2].color.magFilter = gl.LINEAR
    this.state[2].color.minFilter = gl.LINEAR
  }

  setupAnimation (preset) {
    let self = this
    // Epsilon Animation
    let eps1 = new TWEEN.Tween(this)
    eps1
      .to({ epsilon: 0.001 }, 10 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)
    // eps1.start(0)

    // Camera location animation
    let ob = {
      x: self.cameraRo[0],
      y: self.cameraRo[1],
      z: self.cameraRo[2]
    }
    function updatePos () {
      self.cameraRo[0] = this.x
      self.cameraRo[1] = this.y
      self.cameraRo[2] = this.z
    }

    let cameraPosTween = new TWEEN.Tween(ob)
    cameraPosTween
      .to({ x: -0.5 }, 10 * 1000)
      .onUpdate(updatePos)

    let cameraPosTween2 = new TWEEN.Tween(ob)
    cameraPosTween2
      .to({ x: 0.5 }, 10 * 1000)
      .onUpdate(updatePos)

    cameraPosTween.chain(cameraPosTween2)
    cameraPosTween2.chain(cameraPosTween)
    // cameraPosTween.start(0)

    // Camera rotation
    function updateRot () {
      self.cameraAngles[0] = this[0]
      self.cameraAngles[1] = this[1]
      self.cameraAngles[2] = this[2]
    }

    let rotObj = [...this.cameraAngles]
    let camRotTween1 = new TWEEN.Tween(rotObj)
    camRotTween1
      .to([0, 0, 0], 0.01 * 1000)
      .onUpdate(updateRot)
      .delay(5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)

    // camRotTween1.start(0)

    // Animation Fractal
    let rotTween1 = new TWEEN.Tween(this.rot2angle)
    rotTween1
      .to([0.687, 0.264, 0.715], 5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)
    let rotTween2 = new TWEEN.Tween(this.rot2angle)
    rotTween2
      .to([0.25, 1.362, 0.234], 5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)
    let rotTween3 = new TWEEN.Tween(this.rot2angle)
    rotTween3
      .to([1.265, 0.844, 0], 5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)
    let rotTweenReturn = new TWEEN.Tween(this.rot2angle)
    rotTweenReturn
      .to([this.rot2angle[0], 0, 0], 5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)

    rotTween1.chain(rotTween2)
    rotTween2.chain(rotTween3)
    rotTween3.chain(rotTweenReturn)
    // rotTween1.start(0)

    // Scale Tween
    let scaleTween1 = new TWEEN.Tween(this)
    scaleTween1
      .to({ scale: 1.53 }, 5 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)
    let scaleTweenReturn = new TWEEN.Tween(this)
    scaleTweenReturn
      .to({ scale: this.scale }, 10 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)

    scaleTween1.chain(scaleTweenReturn)
    // scaleTween1.start(0)

    // Offset Tween
    let offsetTween1 = new TWEEN.Tween(this.offset)
    offsetTween1
      .to([
        this.offset[0],
        0.961,
        this.offset[2]
      ], 60 * 1000)
      .easing(TWEEN.Easing.Quadratic.InOut)

    offsetTween1.start(0)
  }

  setupAudio () {
    return new Promise((resolve, reject) => {
      const audioCtx = new (window.AudioContext || window.webkitAudioContext)()

      const output = audioCtx.createGain()
      output.gain.setValueAtTime(0.2, audioCtx.currentTime)
      output.connect(audioCtx.destination)

      const start = audioCtx.currentTime + 5 * (1 + Math.floor(window.performance.now() / (5 * 1000))) + 2.20

      // Tones
      const swell1 = createSwell(audioCtx, 'E2', start, 5)
      swell1.gain.setValueAtTime(0.5, start + 0.001)
      swell1.connect(output)

      // Low tone
      const lowTone = audioCtx.createOscillator()
      lowTone.type = 'sawtooth'
      lowTone.frequency.setValueAtTime((new Octavian.Note('D#2')).frequency, start)

      const lowToneGain = audioCtx.createGain()
      lowToneGain.gain.setValueAtTime(0.4, start)

      const lowToneFilter = audioCtx.createBiquadFilter()
      lowToneFilter.type = 'lowpass'
      lowToneFilter.frequency.setValueAtTime(0, start)
      lowToneFilter.frequency.linearRampToValueAtTime(1000, start + 5 / 2)
      lowToneFilter.frequency.linearRampToValueAtTime(0, start + 5)

      lowTone.connect(lowToneFilter)
      lowToneFilter.connect(lowToneGain)
      lowToneGain.connect(output)

      lowTone.start(start)

      const start2 = start + 5

      // Tones
      const swell2 = createSwell(audioCtx, 'E2', start2, 5)
      swell2.gain.setValueAtTime(0.5, start2 + 0.001)
      swell2.connect(output)

      // Low tone
      const lowTone2 = audioCtx.createOscillator()
      lowTone2.type = 'sawtooth'
      lowTone2.frequency.setValueAtTime((new Octavian.Note('D#2')).frequency, start2)

      const lowToneGain2 = audioCtx.createGain()
      lowToneGain2.gain.setValueAtTime(0.4, start2)

      const lowToneFilter2 = audioCtx.createBiquadFilter()
      lowToneFilter2.type = 'lowpass'
      lowToneFilter2.frequency.setValueAtTime(0, start2)
      lowToneFilter2.frequency.linearRampToValueAtTime(1000, start2 + 5 / 2)
      lowToneFilter2.frequency.linearRampToValueAtTime(0, start2 + 5)

      lowTone2.connect(lowToneFilter2)
      lowToneFilter2.connect(lowToneGain2)
      lowToneGain2.connect(output)

      lowTone2.start(start2)
    })
  }

  enableEvents () {
    if (this.capturing) return
    this.resizeBound = this.resizeBound || this.resize.bind(this)
    window.addEventListener('resize', this.resizeBound, true)
    window.addEventListener('vrdisplaypresentchange', this.resizeBound, true)
  }

  disposeEvents () {
    window.removeEventListener('resize', this.resizeBound, true)
    window.removeEventListener('vrdisplaypresentchange', this.resizeBound, true)
  }

  glInit (gl) {
    // Turn off depth test
    gl.disable(gl.DEPTH_TEST)

    // Create fragment shader
    this.shader = createShader(gl, glslify('./vert.glsl'), glslify('./frag.glsl'))
    this.bright = createShader(gl, glslify('./vert.glsl'), glslify('./bright.glsl'))
    this.bloom = createShader(gl, glslify('./vert.glsl'), glslify('./bloom.glsl'))
    this.finalPass = createShader(gl, glslify('./vert.glsl'), glslify('./final-pass.glsl'))

    this.setupFBOs(gl)

    this.shader.attributes.position.location = 0
  }

  kifsM (t = 0, scale = this.scale, offset = this.offset) {
    this.shader.uniforms.scale = scale
    this.shader.uniforms.offset = offset

    // Scale and Offset
    let _kifsM

    if (MANDELBOX) {
      _kifsM = mat4.fromValues(
        1, 0, 0, -offset[0],
        0, 1, 0, -offset[1],
        0, 0, 1, -offset[2],
        0, 0, 0, 1)
    } else {
      _kifsM = mat4.fromValues(
        scale, 0, 0, -offset[0] * (scale - 1),
        0, scale, 0, -offset[1] * (scale - 1),
        0, 0, scale, -offset[2] * (scale - 1),
        0, 0, 0, 1)
    }

    const angleX = this.rot2angle[0]
    const axisX = vec3.fromValues(1, 0, 0)
    mat4.multiply(_kifsM, rot4(axisX, angleX), _kifsM)

    // Y-centric
    const angleY = this.rot2angle[1]
    const axisY = vec3.fromValues(0, 1, 0)
    mat4.multiply(_kifsM, rot4(axisY, angleY), _kifsM)

    // Z-centric
    const angleZ = this.rot2angle[2]
    const axisZ = vec3.fromValues(0, 0, 1)
    mat4.multiply(_kifsM, rot4(axisZ, angleZ), _kifsM)

    return _kifsM
  }

  resize (e) {
    let canvas = this.canvas
    fit(canvas, window, dpr)
    let dim = this.getDimensions()

    this.state[0].shape = dim
    this.state[1].shape = dim
    this.state[2].shape = dim
  }

  tick (t) {
    let gl = this.gl

    let dim = this.getDimensions()

    this.shader.bind()

    // gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    // gl.clearColor(0, 0, 0, 0)
    // gl.viewport(0, 0, dim[0], dim[1])

    this.update(t)
    this.render(t)
  }

  getCamera (t) {
    t /= 1000
    let cameraMatrix = mat4.create()

    // LookAt
    if (this.LOOKAT) {
      mat4.lookAt(cameraMatrix, this.cameraRo, vec3.fromValues(0, 0, 0), vec3.fromValues(0, 1, 0))
    } else {
      const angleX = this.cameraAngles[0]
      const axisX = vec3.fromValues(1, 0, 0)
      mat4.multiply(cameraMatrix, rot4(axisX, angleX), cameraMatrix)

      // Y-centric
      const angleY = this.cameraAngles[1]
      const axisY = vec3.fromValues(0, 1, 0)
      mat4.multiply(cameraMatrix, rot4(axisY, angleY), cameraMatrix)

      // Z-centric
      const angleZ = this.cameraAngles[2]
      const axisZ = vec3.fromValues(0, 0, 1)
      mat4.multiply(cameraMatrix, rot4(axisZ, angleZ), cameraMatrix)
    }

    this.cameraMatrix = cameraMatrix
    return [this.cameraRo, cameraMatrix]
  }

  update (t) {
    t = (window.time !== undefined) ? window.time : t
    TWEEN.update(t)

    if (this.tMatCap) {
      this.shader.uniforms.tMatCap = this.tMatCap.bind(0)
    }

    // Update audio
    if (this.analyser) {
      this.analyser.getByteTimeDomainData(this.audioTexArray)
      this.audioTex.setPixels(this.audioNday)
      this.shader.uniforms.audioTexture = this.audioTex.bind(1)
    }

    this.shader.uniforms.epsilon = this.epsilon

    // this.cameraRo = vec3.fromValues(0.01 * Math.sin(Math.PI * t / 1000 / 5), 0.05 * Math.sin(Math.PI * t / 1000 / 2), 1.7)
    let updates = this.getCamera(t)
    this.shader.uniforms.cameraRo = updates[0]
    this.shader.uniforms.cameraMatrix = (updates[1])

    this.shader.uniforms.kifsM = this.kifsM(t, this.scale, this.offset)
    this.shader.uniforms.kifsM2 = this.kifsM(t, this.scale2, this.offset2)
    this.shader.uniforms.offsetC = this.offsetC

    this.shader.uniforms.angle1C = this.angle1C
    this.shader.uniforms.angle2C = this.angle2C
    this.shader.uniforms.angle3C = this.angle3C
  }

  bloomBlur (gl, t) {
    let dim = this.getDimensions()

    // Brightness pass
    let base = this.state[0].color[0]
    this.state[1].bind()
    this.bright.bind()
    this.bright.uniforms.minBright = BLOOM_MIN_BRIGHTNESS
    this.bright.uniforms.buffer = base.bind(0)
    this.bright.uniforms.resolution = dim
    drawTriangle(gl)

    for (let i = 0; i < BLOOM_PASSES; i++) {
      // Horizontal Blur
      let brightLayer = this.state[1].color[0]
      this.state[2].bind()

      this.bloom.bind()
      this.bloom.uniforms.buffer = brightLayer.bind(1)
      this.bloom.uniforms.resolution = dim
      this.bloom.uniforms.direction = [1, 0]
      this.bloom.uniforms.time = this.getTime(t)
      drawTriangle(gl)

      // Vertical Blur
      let prev = this.state[2].color[0]
      this.state[1].bind()

      this.bloom.uniforms.buffer = prev.bind(2)
      this.bloom.uniforms.resolution = dim
      this.bloom.uniforms.direction = [0, 1]
      this.bloom.uniforms.time = this.getTime(t)
      drawTriangle(gl)
    }

    // Additive blending
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    this.finalPass.bind()
    this.finalPass.uniforms.base = this.state[0].color[0].bind(3)
    this.finalPass.uniforms.buffer = this.state[1].color[0].bind(4)
    this.finalPass.uniforms.resolution = dim
    this.finalPass.uniforms.time = this.getTime(t)
    this.finalPass.uniforms.wet = BLOOM_WET
    drawTriangle(gl)
  }

  getTime (t) {
    return window.time || t / 1000
  }

  defaultSceneRender (_, t) {
    drawTriangle(this.gl)
  }

  render (t) {
    let { shader, gl } = this

    if (BLOOM) {
      this.state[0].bind()
    }

    shader.uniforms.time = this.getTime(t)
    shader.uniforms.BLOOM = BLOOM
    this.sceneRender(shader, t)

    if (BLOOM) {
      this.bloomBlur(gl, t)
    }
  }

  run () {
    this.canvas.style.display = null
    this.resize()

    this.enableEvents()
  }

  stop () {
    this.canvas.style.display = 'none'
    this.disposeEvents()
  }
}
