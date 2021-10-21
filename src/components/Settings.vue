<template>
	<div class="col-4">
		<div class="card" v-show="advanced_menu">
			<div class="card-header d-flex">
				<span class="card-title">Advanced configuration</span>
				<button class="btn-close ms-auto" v-on:click="advanced_menu = false"></button>
			</div>
			<div class="card-body text-start">
				<label for="bpm">tempo clock</label>
				
				<div class="input-group input-group-sm mb-1 w-50">
					<span class="input-group-text">bpm</span>
					<input type="number" class="form-control form-control-sm" placeholder="value" :value="config.bpm" min="0" 
					@change="changeBpm($event)"  
					v-bind:disabled="!disabled()" >
				</div>	

				<label for="manufacturer">sysex manufacturer id</label>
				<div class="d-flex d-row">
					<div class="input-group input-group-sm mb-1">
						<span class="input-group-text">Supercollider </span>
						<input type="number" class="form-control form-control-sm" placeholder="id" :value="config.sc_sysex_id" min="0" max="127" step="1" 
						@change="changeSysex_id($event,'sc_sysex_id')"
						v-bind:disabled="!disabled()" >
					</div>
					<div class="input-group input-group-sm mb-1">
						<span class="input-group-text">Webmidi</span>
						<input type="number" class="form-control form-control-sm" placeholder="id" :value="config.webmidi_sysex_id" min="0" max="127" step="1"
						@change="changeSysex_id($event,'webmidi_sysex_id')"
						v-bind:disabled="!disabled()" >
					</div>
				</div>

				<label for="funid">Function id</label>
				<div class="input-group input-group-sm mb-1 w-50"
					v-for="fun in Object.keys(config.sysex_msgs)">
					<span class="input-group-text">{{fun}}</span>
					<input type="number" class="form-control form-control-sm" placeholder="id" :value="config.sysex_msgs[fun].id" min="0" max="127"  step="1" 
					@change="changeFun_id($event,fun)"
					v-bind:disabled="!disabled()" >
				</div>	

				<label for="limits">limits</label>
				<div class="input-group input-group-sm mb-1 w-75"
					v-for="prop in Object.keys(config.limits)">
					<span class="input-group-text">{{prop}}</span>
					<input type="number" class="form-control form-control-sm" v-bind:placeholder="limit"
					v-for="limit in Object.keys(config.limits[prop]).filter(x => x!='validate') " 
					:name="limit"
					:value="config.limits[prop][limit]"
					@change="changeLimits($event, prop, limit)"
					v-bind:disabled="!disabled()" >
				</div>	
			</div>
		</div>







		<div class="card" v-show="!advanced_menu">
			<div class="card-header">
				<span class="card-title">Options</span>
				<span class="badge" :class="(online ? 'bg-success' : 'bg-warning')" >SC: {{(online ? 'online': 'offline')}}</span>
			</div>
			<div class="card-body text-start">
				<div class="input-group input-group-sm mb-1">
					<span class="input-group-text">Output</span>
					<select id="output" class="form-control form-select-sm" name="output" @change="$emit('changeOutput', $event.target.value)" v-bind:disabled="!disabled()">
						<option value="" disabled selected>output</option>
						<option v-for="output in midi.outputs"  :value="output.id">{{output.name}} {{output.manufacturer}}</option>
					</select>
					<span class="input-group-text" :class="output.state  == 'connected' ? 'bg-success' : 'bg-warning'">{{output.state}}</span>
				</div>

				<div class="input-group input-group-sm mb-1" v-if="midi.enabled">
					<span class="input-group-text">Input</span>
					<select id="input" class="form-control form-select-sm" name="input" @change="$emit('changeInput', $event.target.value)" v-bind:disabled="!disabled()">
						<option value="" disabled selected>input</option>
						<option v-for="input in midi.inputs"  :value="input.id">{{input.name}} {{input.manufacturer}}</option>
					</select>
					<span class="input-group-text" :class="input.state  == 'connected' ? 'bg-success' : 'bg-warning'">{{input.state}}</span>
				</div>

				<div class="input-group input-group-sm mb-1">
					<span class="input-group-text">samples</span>
					<input type="file" multiple  accept=".wav,.aiff" class="form-control form-control-sm" @change="$emit('changeSamples', $event.target)" v-bind:disabled="!disabled()">
				</div>

				<div class="input-group input-group-sm mb-1">
					<span class="input-group-text">basepath</span>
					<input class="form-control form-control-sm" type="text" v-bind:disabled="!disabled()" @change="$emit('changeBasepath',$event.target.value)">
				</div>
				<a href="#" class="link-secondary" v-on:click="advanced_menu = true">Advanced Config.</a>
				<pre class="text-start">{{log}}</pre>
			</div>
			

			<div class="card-footer">
				<button class="btn btn-outline-secondary" v-bind:disabled="!disabled()" v-on:click.once="$emit('genScript',$event.target)">generate</button>

				<button class="btn btn-outline-secondary" v-on:click="$emit('addSeq')" v-bind:disabled="code=='' || samples.every(x=> x.frames==0) ">add seq</button>
			</div>
		</div>
	</div>
</template>

<script lang="ts">
import Vue from 'vue'
import Component from "vue-class-component";


@Component({
	props:[
		'input',
		'output',
		'midi',
		'config',
		'samples',
		'online',
		'log',
		'code',
	]
})
export default class settings extends Vue{
	advanced_menu = false

	changeBpm(event:InputEvent){
		const value = isNaN(parseFloat( (<HTMLInputElement>event.target).value)) ? -1 : parseFloat( (<HTMLInputElement>event.target).value)
		if( value <0 || value > 127 ){
			(<HTMLInputElement>event.target).value = this.$props.config.bpm
		}else{	
			this.$props.config.bpm = value
		}
	}
	changeSysex_id(event:InputEvent,name:string){
		const value = isNaN(parseInt( (<HTMLInputElement>event.target).value)) ? -1 : parseInt( (<HTMLInputElement>event.target).value)
		const ids = [this.$props.config.webmidi_sysex_id, this.$props.config.sc_sysex_id]
		if( value <0 || value > 127 || ids.indexOf(value) >-1){
			(<HTMLInputElement>event.target).value = this.$props.config[name]
		}else{	
			this.$props.config[name] = value
		}
	}
	

	changeFun_id(event:InputEvent, name:string){
		const value = isNaN(parseInt( (<HTMLInputElement>event.target).value)) ? -1 : parseInt( (<HTMLInputElement>event.target).value)
		const ids = Object.values(this.$props.config.sysex_msgs).map( function(x:any){  return x.id == undefined ? -1 : x.id})

		console.debug((<HTMLInputElement>event.target).value, typeof value, value, value < 0 , value>127, ids.indexOf(value), ids )
		if( value <0 || value > 127 || ids.indexOf(value) > -1){
			(<HTMLInputElement>event.target).value = this.$props.config.sysex_msgs[name].id
		}else{
			this.$props.config.sysex_msgs[name].id = value
		}
	}

	changeLimits(event:InputEvent, prop:string, limit:string){
		const value:null|number = isNaN(parseFloat( (<HTMLInputElement>event.target).value)) ? null : parseFloat( (<HTMLInputElement>event.target).value)
		if(value==null){
			(<HTMLInputElement>event.target).value = this.$props.config.limits[prop][limit]
			return false
		}
		
		if(this.$props.config.limits[prop].hasOwnProperty('min') && this.$props.config.limits[prop].hasOwnProperty('max')){
			if(limit == 'min'){
				if(value < this.$props.config.limits[prop].max){
					this.$props.config.limits[prop].min = value
				}else{
					(<HTMLInputElement>event.target).value = this.$props.config.limits[prop].min
				}
			}else{
				if(value > this.$props.config.limits[prop].min){
					this.$props.config.limits[prop].max = value
				}else{
					(<HTMLInputElement>event.target).value = this.$props.config.limits[prop].max
				}
			}
		}else{
			if(value >= 0){
				this.$props.config.limits[prop].max = value
			}else{
				(<HTMLInputElement>event.target).value = this.$props.config.limits[prop][limit]	
			}
		
		}
	}

	disabled(){
		return ! (this.$props.midi.sysexEnabled && this.$props.input.addListener != undefined && this.$props.output.sendSysex!= undefined && this.$props.samples.length > 0 && this.$props.code !="")
	}
}
</script>
