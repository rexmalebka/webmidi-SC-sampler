<template>
<div class="container-fluid">
	<div class="row g-5 py-2">
		<Settings 
			v-bind:midi="midi"

			v-bind:input="input" 
			v-bind:output="output" 
			
			v-bind:config="config"

			v-bind:online="online"
			v-bind:samples="config.samples"

			v-bind:log="log"
			v-bind:code="code"

			@changeInput="changeInput"
			@changeOutput="changeOutput"

			@changeSamples="changeSamples"

			@changeBasepath="changeBasepath"

			@genScript="genScript"
			@addSeq="addSeq"
		></Settings>
		<Sequence v-for="(seq,i) in sequences"
			:key="i"
			v-bind:samples="config.samples"

			v-bind:seq_id="seq.seq_id"
			v-bind:sample="seq.sample"
			v-bind:pos="seq.pos"
			v-bind:rate="seq.rate"
			v-bind:tempo="seq.tempo"
			v-bind:amp="seq.amp"
			v-bind:muted="seq.muted"
			v-bind:limits="config.limits"

			v-bind:global_beat="global_beat"
			v-bind:global_time="global_time"
			v-bind:seq_beat="seq_beat"
			v-bind:seq_time="seq_time"
			
			@delSeq="deleteSeq"
			@log="(value) => log=value"

			@changeSample="changeSeqSample"
			@changeMuted="changeSeqMuted"
			@changePos="changeSeqPos"
			@changeRate="changeSeqRate"
			@changeTempo="changeSeqTempo"
			@changeAmp="changeSeqAmp"
		></Sequence>
	</div>
</div>
</template>

<style lang="scss" >
@import "./custom.scss";
@import "bootstrap";
</style>

<script lang="ts">
import 'bootstrap'
import "./scss/sequence.scss";
import "bootstrap/scss/bootstrap.scss";

import Vue from 'vue'
import Component from "vue-class-component";

import Sequence from './components/Sequence.vue'
import Settings from './components/Settings.vue'

import SCScript from './SCgen'
import {Config,sample} from './Config'

import {WebMidi} from "webmidi/dist/webmidi.esm.js";


interface sequence{
	'seq_id':number;
	'sample':sample;
	'pos':number;
	'rate':number;
	'amp':number;
	'tempo':number;
	'muted':boolean;
	'beat':number;
	'time':number;
}

@Component({
	components: {
		Settings,
		Sequence
	}
})
export default class app extends Vue{
	config:Config = Config 
	sequences:sequence[] = []

	output : any= {
		id: '',
		state: 'disconnected'
		}
	input :  any = {
			id: '',
		state: 'disconnected',
		}

	global_time = 0
	global_beat = 0

	get seq_beat(){
		const beats = []
		for(var i=0;i<this.sequences.length; i++){
			beats[i] = this.sequences[i].beat
		}
		return beats
	}

	get seq_time(){
		const time = []
		for(var i=0;i<this.sequences.length; i++){
			time[i] = this.midi.time - this.sequences[i].time
		}
		return time
	}
	

	midi = WebMidi
	online = false

	log = "Hello"

	code = ""

	format_num(num:number):number[]{
		// [pos, int_leng, dec_leng, ...int, ...dec]
		if(isNaN(num)) return []
		let [intPart,decPart] = JSON.stringify(Math.abs(num)).split('.')
		const intPartArr = Array.from(intPart.match(/.{1,2}/g) || []).map((x:string)=> parseInt(x))
		const decPartArr = Array.from((decPart || '0').substr(0,4).match(/.{1,2}/g) || []).map((x:string)=> parseInt(x))

		return [ num > 0 ? 1:0, intPartArr.length, decPartArr.length, ...intPartArr, ...decPartArr]
	}

	retrieve_num(numArr:number[]):number{
		if(numArr.length<5) return NaN
		const sign:number = numArr[0] ? 1 : -1
		const intPart = numArr.slice(3, 3+numArr[1]).join('')
		const decPart = numArr.slice(2+numArr[1]+numArr[2]).join('')

		const num = parseFloat(`${intPart}.${decPart}`) * sign
		return num

	}

	listener(app:any){
		return function(e:any){
			const data = e.data
			if(data[1] == app.config.sc_sysex_id){
				const fun_id = Object.keys(app.config.sysex_msgs).map(x=> app.config.sysex_msgs[x].id).indexOf(data[2])
				if(fun_id >= 0){
					const fun = app.config.sysex_msgs[Object.keys(app.config.sysex_msgs)[fun_id]].fun
					const args = data.slice(3,-1)
					fun.bind(app)(...args)
				}
			}
		}
			
	}


	startListener(){
		if(this.midi.sysexEnabled && this.input.addListener){
			console.debug('adding listener')
			this.input.removeListener()
			this.input.addListener('sysex','all',this.listener(this)) 
			return true
		}else{
			return false
		}
	}


	sendMidi(msg:number[]){
		if(this.midi.sysexEnabled &&  this.output.sendSysex && this.input.addListener){
			this.output.sendSysex(this.config.webmidi_sysex_id, msg)
		}

	}

	
	pingSC(){ this.sendMidi([this.config.sysex_msgs.ping.id]) }

	loadSamples(){
		this.log = "loading Buffer samples"
		this.sendMidi([this.config.sysex_msgs.loadSamples.id])
	}

	tick(){
		this.sendMidi([this.config.sysex_msgs.tick.id,0])
	}


	genScript(target:HTMLButtonElement){
		const code = SCScript(this.config)
		console.debug("generating script")
		target.disabled = true
		this.code = code

		const app = this
		
		this.online = false
		this.pingSC()

		new Promise((res, rej)=>{
			setInterval(function(){
				if(app.online) res(null)
				app.online = false
				app.pingSC.bind(app)()
			},2000)
		}).then(()=>{
			app.online = true
			app.log = "loading samples..."
			app.loadSamples.bind(app)()
			
			const id = setInterval(function(){
				if(app.config.samples.every( (x:any)=> x.frames>0) ){
					clearInterval(id)
					app.log = "all samples are loaded."
					app.tick.bind(app)()
				}
			},1000)
		})
	}




	changeInput(id:string){
		if(this.midi.enabled){
			const port = this.midi.getInputById(id)
			if(port){
				this.input = port
				this.log = `midi input set to: "${port.name} ${port.manufacturer}"(${port.id})`
				this.startListener()
			}
		}
	}

	changeOutput(id:string){
		if(this.midi.enabled){
			const port = this.midi.getOutputById(id)
			if(port){
				this.output = port
				this.log =`midi output set to: "${port.name} ${port.manufacturer}"(${port.id})`
			}
		}
	}

	changeBasepath(basepath:string){ this.config.basepath = basepath}

	changeSamples(target:HTMLInputElement){
		const files = target.files
		const names = Array.from(files ? files : []).filter(x=> x.name.endsWith('wav') || x.name.endsWith('aiff')).map(x=> x.name)
		if(names.length != 0){
			this.config.samples = names.map((x,i)=> {return {id: i,name: x, frames:0} } )
			this.log = `adding ${names.length} samples: `+names.map(x=> `"${x}"`).join(',')
		}else{
			target.value = ""
		}
	}







	addSeq(){
		const t = this.midi.time
		const i = this.sequences.push({
			seq_id:this.sequences.length,
			sample:{id:0, name:"", frames:0},
			pos:0,
			rate:1,
			tempo:1,
			amp:1,
			muted:false,
			beat:0,
			time:t
		})
		const seq = this.sequences[i-1]

		/*
		0 sample_id
		1 start
		2 rate
		3 tempo
		4 amp
		*/
		this.sendMidi([
			this.config.sysex_msgs.schedSeq.id, 
			seq.seq_id, 
			0,
			seq.sample.id
		]) 
		this.sendMidi([
			this.config.sysex_msgs.schedSeq.id, 
			seq.seq_id, 
			1,
			...this.format_num(seq.pos)
		]) 
		this.sendMidi([
			this.config.sysex_msgs.schedSeq.id, 
			seq.seq_id, 
			2,
			...this.format_num(seq.rate)
		]) 
		this.sendMidi([
			this.config.sysex_msgs.schedSeq.id, 
			seq.seq_id, 
			3,
			...this.format_num(seq.tempo)
		]) 
		this.sendMidi([
			this.config.sysex_msgs.schedSeq.id, 
			seq.seq_id, 
			4,
			...this.format_num(seq.amp)
		]) 
		this.log = `syncing sequencer #${this.sequences.length-1}` 
	}
	
	deleteSeq(id:number){
		if(this.sequences[id]){	
			this.sequences.splice(id,1)
			this.sequences = this.sequences.map( (seq, i) => {
				seq.seq_id = i
				return seq
			})
		}
	}


	changeSeqSample({id,sample_id}:{id:number, sample_id:number}){
		if(this.sequences[id] && this.config.samples[sample_id]){
			this.sequences[id].sample = this.config.samples[sample_id]	
			this.sendMidi([
				this.config.sysex_msgs.schedSeq.id, 
				this.sequences[id].seq_id, 
				0,
				sample_id
			]) 
		}
	}

	changeSeqMuted({seq_id,muted}:{seq_id:number,muted:boolean}){
		if(this.sequences[seq_id]){
			this.sequences[seq_id].muted = !muted

			this.sendMidi([
				this.config.sysex_msgs.schedSeq.id, 
				seq_id, 
				4,
				...this.format_num(0)
			]) 
		}
	}
	
	changeSeqPos({seq_id,pos}:{seq_id:number,pos:number}){
		console.info("changing pos: ",pos)
		if(this.sequences[seq_id] ){
			if(pos != this.sequences[seq_id].pos) {
				this.sequences[seq_id].pos = pos
				this.sendMidi([
					this.config.sysex_msgs.schedSeq.id, 
					seq_id, 
					1,
					...this.format_num( pos)
				]) 
			}
		}
	}

	changeSeqRate({seq_id,rate}:{seq_id:number,rate:number}){
		if(this.sequences[seq_id]){
			if(rate != this.sequences[seq_id].rate) {
				this.sequences[seq_id].rate = rate
				this.sendMidi([
					this.config.sysex_msgs.schedSeq.id, 
					seq_id, 
					2,
					...this.format_num(rate)
				]) 
			}
		}
	}

	changeSeqTempo({seq_id,tempo}:{seq_id:number,tempo:number}){
		if(this.sequences[seq_id]){
			if(tempo != this.sequences[seq_id].tempo) {
				this.sequences[seq_id].tempo = tempo
				this.sendMidi([
					this.config.sysex_msgs.schedSeq.id, 
					seq_id, 
					3,
					...this.format_num(tempo)
				]) 
			}
		}
	}

	changeSeqAmp({seq_id,amp}:{seq_id:number,amp:number}){
		if(this.sequences[seq_id]){
			if(amp != this.sequences[seq_id].amp) {
				this.sequences[seq_id].amp = amp
				this.sendMidi([
					this.config.sysex_msgs.schedSeq.id, 
					seq_id, 
					4,
					...this.format_num(amp)
				]) 
			}
		}
	}
	





	created(){
		const app = this
		WebMidi.enable({
			callback: function(err:any):void{
				if(err){
					console.info('midi request failed', err)
				}else{
					app.midi = WebMidi
					console.info("midi request succeded")
				}
			},
			sysex: true
		})
	}
}
</script>
