<template>
	<div class="col-3">
		<div class="card">
			<div class="card-header input-group input-group-sm bm-1">

					<span class="input-group-text" >{{seq_id}}</span>
					<div class="input-group-text">
						<div class="form-check form-switch">
							<input class="form-check-input" checked type="checkbox" @change="$emit('changeMuted', {seq_id:seq_id, muted:$event.target.checked})">
						</div>
					</div>
					<select  class="form-select form-select-sm" name="samples" @change="$emit('changeSample', {id:seq_id, sample_id:$event.target.value})">
						<option value="" disabled selected>sample</option>
						<option v-for="(sample,i) in samples" :key="i" :value="i">{{sample.name}}</option>
					</select>
					<div class="input-group-text">
						<button type="button" class="btn-close" aria-label="Close" v-on:click="$emit('delSeq',seq_id)"></button>
					</div>
			</div>












			<div class="card-body">
				<div class="d-flex">
					<label for="sample position">sample position</label>
					<span class="ms-auto">{{pos}}/{{sample.frames}}</span>
				</div>
				<div class="input-group input-group-sm mb-1">
					<button class="input-group-text" v-on:click="togglePos()">toggle</button>
					<input class="form-control form-control-sm" type="text" 
						v-show="!rangePos"
						v-on:keyup.enter="changeposFunc($event.target.value)"
						v-bind:disabled="sample.name==''">
					<input type="range" class="form-control form-control-sm form-range" min="0" :max="sample.frames" step="0.1" 
					v-bind="pos" 
					v-show="rangePos" 
					v-bind:disabled="sample.name==''"
					v-on:mouseup="$emit('changePos',{seq_id:seq_id, pos:$event.target.value})">
				</div>

				<div class="d-flex">
					<label for="rate">buffer rate</label>
					<span class="ms-auto">{{rate}}</span>
				</div>
				<div class="input-group input-group-sm mb-1">
					<button class="input-group-text" v-on:click="toggleRate()">toggle</button>
					<input class="form-control form-control-sm" type="text" 
						v-show="!rangeRate"
						v-on:keyup.enter="changerateFunc($event.target.value)"
						v-bind:disabled="sample.name==''">
					<input type="range" class="form-control form-control-sm form-range" 
					:min="limits.rate.min" 
					:max="limits.rate.max" step="0.1" 
					v-bind="rate" 
					v-show="rangeRate" 
					v-bind:disabled="sample.name==''"
					v-on:mouseup="$emit('changeRate',{seq_id:seq_id, rate:$event.target.value})">
				</div>


				<div class="d-flex">
					<label for="tempo">sequencer tempo</label>
					<span class="ms-auto">{{tempo}}</span>
				</div>
				<div class="input-group input-group-sm mb-1">
					<button class="input-group-text" v-on:click="toggleTempo()">toggle</button>
					<input class="form-control form-control-sm" type="text" 
						v-show="!rangeTempo"
						v-on:keyup.enter="changetempoFunc($event.target.value)"
						v-bind:disabled="sample.name==''">
					<input type="range" class="form-control form-control-sm form-range" 
					:min="0" 
					:max="limits.tempo.max" step="0.1" 
					v-bind="tempo" 
					v-show="rangeTempo" 
					v-bind:disabled="sample.name==''"
					v-on:mouseup="$emit('changeTempo',{seq_id:seq_id, tempo:$event.target.value})">
				</div>
				
				<div class="d-flex">
					<label for="amp">amp</label>
					<span class="ms-auto">{{amp}}</span>
				</div>
				<div class="input-group input-group-sm mb-1">
					<button class="input-group-text" v-on:click="toggleAmp()">toggle</button>
					<input class="form-control form-control-sm" type="text" 
						v-show="!rangeAmp" 
						v-on:keyup.enter="changeampFunc($event.target.value)"
						v-bind:disabled="sample.name==''">

					<input type="range" class="form-control form-control-sm form-range" 
					:min="0" 
					:max="limits.amp.max" step="0.1" 
					v-bind="amp"
					v-show="rangeAmp"
					v-bind:disabled="sample.name==''"
					v-on:mouseup="$emit('changeAmp',{seq_id:seq_id, amp:$event.target.value})">
				</div>

				


				
			</div>
			<div class="card-footer d-flex">
				<span class="badge rounded-circle p-1 m-auto" :class="beating ? 'bg-danger' : 'bg-secondary'" >
					<div class="visually-hidden">Heartbeat</div>
				</span>
				<pre class="text-start text-wrap m-1 w-100">{{log}}</pre>
			</div>
		</div>
	</div>
</template>


<script lang="ts">
/*import Component from 'vue-class-component'
import Vue from 'vue'i
import Watch from 'vue-class-component'
*/
import { Component, Watch, Vue } from 'vue-property-decorator'


@Component({
	props:[
		'seq_id',
		'samples',
		'sample',
		'pos',
		'rate',
		'tempo',
		'amp',
		'limits',
		'muted',
		'global_beat',
		'global_time',
		'seq_beat',
		'seq_time'
	],



})
export default class Sequence extends Vue{

	rangePos = false
	rangeRate = false
	rangeTempo = false
	rangeAmp = false

	posFunc = function(b:any,t:any):number{ return 0 }
	rateFunc = function(b:any,t:any):number{ return 0 }
	tempoFunc = function(b:any,t:any):number{ return 0 }
	ampFunc = function(b:any,t:any):number{ return 0 }

	beating = false
	log = ""

	@Watch('seq_beat')
	onChangeBeat(new_value:any, old_value:any){
		const app = this

		if(new_value != old_value){
			this.beating = true
			setTimeout(()=>{app.beating = false },250)
		}
			

		console.debug(this.posFunc, this.tempoFunc, )
		this.$emit("changePos", { 
			seq_id: this.$props.seq_id, 
			pos: this.rangePos ? this.$props.pos :  this.posFunc(this.beats, this.time) 
		})
		
		this.$emit("changeRate", { 
			seq_id: this.$props.seq_id, 
			rate: this.rangeRate ? this.$props.rate :  this.rateFunc(this.beats, this.time) 
		})

		this.$emit("changeTempo", { 
			seq_id: this.$props.seq_id, 
			tempo: this.rangeTempo ? this.$props.tempo :  this.tempoFunc(this.beats, this.time) 
		})

		this.$emit("changeAmp", { 
			seq_id: this.$props.seq_id, 
			amp: this.rangeAmp ? this.$props.amp :  this.ampFunc(this.beats, this.time) 
		})
	}

	changeposFunc(new_value:string){
		const seq = this

		const fun = function(b:any,t:any):number{
			const old_pos:number = seq.$props.pos
			try{
				let val:any = eval(new_value)
				seq.log = "" 
				if(val.constructor == Function){
					val = val()
				}
				
				return isNaN(val) ? old_pos : val
			} catch(err){
				seq.log = `Error in pos: "${err}"` 
			}
			return old_pos
		}

		this.posFunc = fun
	}
	
	changerateFunc(new_value:string){
		const seq = this

		const fun = function(b:any,t:any):number{
			const old_rate:number = seq.$props.rate
			try{
				let val:any = eval(new_value)
				seq.log = "" 
				if(val.constructor == Function){
					val = val()
				}
				
				return isNaN(val) ? old_rate : val
			} catch(err){
				seq.log = `Error in pos: "${err}"` 
			}
			return old_rate
		}

		this.rateFunc = fun
	}

	changetempoFunc(new_value:string){
		const seq = this

		const fun = function(b:any,t:any):number{
			const old_tempo:number = seq.$props.tempo
			try{
				let val:any = eval(new_value)
				seq.log = "" 
				if(val.constructor == Function){
					val = val()
				}
				
				return isNaN(val) ? old_tempo : val
			} catch(err){
				seq.log = `Error in pos: "${err}"` 
			}
			return old_tempo
		}

		this.tempoFunc = fun
	}

	changeampFunc(new_value:string){
		const seq = this

		const fun = function(b:any,t:any):number{
			const old_amp:number = seq.$props.amp
			try{
				let val:any = eval(new_value)
				seq.log = "" 
				if(val.constructor == Function){
					val = val()
				}
				
				return isNaN(val) ? old_amp : val
			} catch(err){
				seq.log = `Error in pos: "${err}"` 
			}
			return old_amp
		}

		this.ampFunc = fun
	}

	get beats(){
		const app = this
		const wrapper :any= function(seq:any){
			if(isNaN(seq)){
				return app.$props.seq_beat[app.$props.seq_id]
			}else{
				return app.$props.seq_beat[seq] || NaN
			}
		}

		wrapper[Symbol.toPrimitive] = function(hint:string){
			return wrapper()
		}

		return wrapper
	}

	set beats(value:any){}

	get time(){
		const app = this
		const wrapper :any= function(seq:any){
			if(isNaN(seq)){
				return app.$props.seq_time[app.$props.seq_id]
			}else{
				return app.$props.seq_time[seq]
			}
		}

		wrapper[Symbol.toPrimitive] = function(hint:string){
			return wrapper()
		}


		return wrapper
	}



	togglePos(){ this.rangePos = !this.rangePos }
	toggleRate(){ this.rangeRate = !this.rangeRate }
	toggleTempo(){ this.rangeTempo = !this.rangeTempo }
	toggleAmp(){ this.rangeAmp = !this.rangeAmp }

	created(){
		console.debug('just created')
		this.changeposFunc(JSON.stringify( this.$props.pos))
		this.changerateFunc(JSON.stringify(this.$props.rate))
		this.changetempoFunc(JSON.stringify(this.$props.tempo))
		this.changeampFunc(JSON.stringify(this.$props.amp))
	}
}

</script>
