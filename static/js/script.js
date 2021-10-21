/*
 * 0 bank select
 * 
 *
 * */

// events
//
// noteon 
// noteoff
// control change
// program change
// pitch bend change
// song select
// sysex system exclusive
//

const webmidi_sysex_id = 111
const sc_sysex_id = 112

const script = `
`

/*
(delta) =>  delta % 16
*/
const sysex_msgs = {
	tick:{
		id: 0,
		fun: function(delta){
			console.debug(delta)
			app.sequences.forEach(function (seq){

				const fun = `( delta, time )=> { return ${seq.amp_func}}`
				try{
					const value = eval(fun)(delta, app.midi.time)
					console.debug("asdf",value)
				}catch(err){
				}
			})
		}
	},
	loadSamples:{
		id:2,
		fun:function(){

		}
	},
	createSeq: {
		id: 1,
		fun: function(){

		}
	}
}
window['sysex_msgs'] = sysex_msgs





const options = Vue.component('options', {
	methods:{
		update_samples: function(event){
			const names = Array.from(event.target.files).filter(x=> x.name.endsWith('wav') || x.name.endsWith('aiff')).map( x => x.name)
			if(names.length == 0){ 
				event.target.value = ""
			}else{
				this.$parent.samples = Object.fromEntries( names.map( x=> [x, {frames:0}]))
			}
		},
		select_output: function(event){
			this.$parent.midi_output = app.midi.getOutputById(event.target.value)
		},
		select_input: function(event){
			this.$parent.midi_input = app.midi.getInputById(event.target.value)
			this.$parent.startListener()
		},
		generate_script(){

		}
	},
	template: `
<div class="col-auto">
				<div class="card border border-3"> 
					<div class="card-header"><span class="card-title">options</span></div>
					<div class="card-body text-center">


						<div class="input-group input-group-sm mb-1">
							<span class="input-group-text" id="start_label">midi Output</span>
							<select id="midi_output" aria-label="midi output" class="form-control form-select-sm" @change="select_output">
								<option selected disabled value="">midi output</option>
								<option v-for="(output, i) in $parent.outputs" :key="i" :value="output.id">{{output.name}} ({{output.manufacturer}})</option>
							</select>
							<span class="input-group-text" id="start_label"  :class="this.$parent.midi_output == '' ? '' : (this.$parent.midi_output.state == 'connected' ? 'bg-success' : 'bg-danger')">{{ this.$parent.midi_output == '' ? '': this.$parent.midi_output.state }}</span>
						</div>

						<div class="input-group input-group-sm mb-1">
							<span class="input-group-text" id="start_label">midi Input</span>
							<select id="midi_input" aria-label="midi input" class="form-control form-select-sm" @change="select_input">
								<option selected disabled value="">midi input</option>
								<option v-for="(input, i) in $parent.inputs" :key="i" :value="input.id">{{input.name}} ({{input.manufacturer}})</option>
							</select>
							<span class="input-group-text" id="start_label"  :class="this.$parent.midi_input == '' ? '' : (this.$parent.midi_input.state == 'connected' ? 'bg-success' : 'bg-danger')">{{ this.$parent.midi_output == '' ? '': this.$parent.midi_input.state }}</span>
						</div>

						<div class="input-group input-group-sm mb-1">
							<span class="input-group-text" id="base_path">Base Path</span>
							<input class="form-control form-control-sm" type="text" placeholder="base path">
						</div>

						<div class="input-group input-group-sm mb-1">
							<input type="file" accept=".wav,.aiff" class="form-control form-control-sm" id="samples" multiple @change="update_samples" :disabled="Object.keys($parent.samples).length >0 || $parent.midi_input == '' || $parent.midi_output == ''">
						</div>
						<button class="btn btn-outline-secondary" :disabled="$parent.midi_output=='' || Object.keys($parent.samples).length == 0" type="button" v-on:click.once="generate_script" >generate script</button>

					</div>
					<div class="card-footer text-mutted">
						<span class="badge bg-secondary">SC {{$parent.sc_state}}</span>
					</div>
				</div>
			</div>
	`
})

const seq = Vue.component('sequence',{
	props: ['index', 'sample', 'start', 'rate', 'tempo', 'amp_func', 'muted', 'interval_ids'],
	data:function(seq){
		return {
		}
	},
	computed: {
		sample_selected: {
			get: function(){
				return this.sample
			},
			set: function(value){
				sample = value
				//this.$parent.sequences[this.index].sample = value
			}
		},
		start_selected: {
			get: function(){
				return this.start
			},
			set: function(value){
				this.start = value
				//this.$parent.sequences[this.index].start = value
			}
		},
		rate_selected: {
			get: function(){
				return this.rate
			},
			set: function(value){
				rate = value
				//this.$parent.sequences[this.index].rate = value
			}
		},
		tempo_selected: {
			get: function(){
				return this.tempo
			},
			set: function(value){
				tempo = value
				//this.$parent.sequences[this.index].tempo = value
			}
		},
		amp_func_selected: {
			get: function(){
				return this.amp_func
			},
			set: function(value){
				amp_func = value
				//this.$parent.sequences[this.index].amp_func = value
			}
		}
	},
	mounted: function(){
		this.update_seq()
	},
	methods: {
		miau: function(){
			console.debug("miau")
		},
		close: function(){
			this.$parent.sequences.splice(this.index,1)
			this.$parent.sequences = this.$parent.sequences.map( (seq, i) => {
				seq.index = i
				return seq
			})
		},
		update_seq:function(amp_func){
			/*
			const card = this.$el
			const width = 7 * Math.trunc(card.offsetWidth / 7 + 3)
			const canvas = card.querySelector("canvas")
			canvas.width = width 
			canvas.height = width * 0.25

			const ctx = canvas.getContext('2d')

			const i = isNaN(parseInt(amp_func)) ? 0 : parseInt(amp_func) 

			const wr = canvas.width / 7 
			const squares = ('0000000'+ (i).toString(2)).slice(-7).split('')

			squares.forEach(function(x,i){
				if(x == '1'){
					ctx.fillStyle = "#FF0000";
					ctx.fillRect(i*wr, 0, wr, canvas.height)
				}else{
					ctx.fillStyle = "#FFFFFF";
					ctx.fillRect(i*wr, 0, wr, canvas.height)
				}
			})
			*/
			//if(this.interval_ids)
		}
	},
	template: `
<div class="col-auto">
	<div class="card">
		<div class="card-header">
			<button type="button" class="btn close btn-outline-secondary" aria-label="Close" v-on:click="close()">
				<span aria-hidden="true">&times;</span>
			</button>
			<select id="sample card-title" name="sample" v-model="sample_selected" @change="$emit('changeSample',sample_selected)">
				<option selected disabled value="">sample</option>
				<option v-for="(sample, i) in Object.keys(this.$parent.samples)" :key="i" :value="sample">{{sample}}</option>
			</select>
		</div>
		<div class="card-body text-center">
			<div class="input-group input-group-sm mb-1">
				<span class="input-group-text" id="start_label">song pos</span>
				<input type="text" class="form-control" placeholder="song pos" @submit="miau"></input>
				<span class="input-group-text">/{{this.$parent.samples.hasOwnProperty(sample) ? this.$parent.samples[sample].frames : 0}}</span>
			</div>
	
			<div class="input-group input-group-sm mb-1">
				<span class="input-group-text" id="rate_label">rate:</span>
				<input type="text" class="form-control" placeholder="rate" v-model="rate"></input>
			</div>
	
			<div class="input-group input-group-sm mb-1">
				<span class="input-group-text" id="tempo_label">tempo</span>
				<input 	type="text" class="form-control" placeholder="tempo" v-model="tempo"></input>
			</div>

			<div class="input-group input-group-sm mb-1">
				<span class="input-group-text" id="amp_label">amp</span>
				<input type="text" class="form-control" placeholder="amp" v-model="amp_func_selected" @change="update_seq(amp_func)"></input>
			</div>

		</div>
		<div class="card-footer text-mutted">
		</div>
	</div>
	</div>
	`
})

const more = Vue.component('more', {
		data: function(){ return {}},
		methods: {
			add: function(){
				if(this.$parent.midi_output!='' && this.$parent.samples.length != 0){
					const i = this.$parent.sequences.length
					this.$parent.sequences.push({
						'index': i ,'sample':'', 'start':null, 'rate':null, 'tempo':null, 'amp_func':null,'sequence':null,
					})
				}
			}
		},
		template: `
<div class="col-auto">
	<div class="card text-center" disabled v-on:click="add()">
		<div class="card-body">
			<span>+</span>
		</div>
	</div>
</div>

	`
})
// ■□


const app = new Vue({
	el: "#app",
	data: {
		sequences: [
			{
			'index':0,'sample':'', 'start':null, 'rate':null, 'tempo':null, 'amp_func':null,'sequence':null,
			},
		],
		samples: {},
		midi_output: '',
		midi_input: '',
		midi: null,
		tick_id: null,
		sc_state: 'disconnected'
	},
	created: function(){

		const app = this
		WebMidi.enable(function(err){
			if(err){
				console.info('midi request failed', err)
			}else{
				app.midi = WebMidi
				sysex_msgs.loadSamples.id
				console.info("midi request succeded",app.midi)
			}
		}, true)
	},
	methods: {
		startListener: function(){
			console.info("starting sysex listener")
			this.midi_input.addListener("sysex", "all", function (e) {
				const data = e.data
				if(data[1] == sc_sysex_id){
					const fun_id = Object.keys(sysex_msgs).map(x=> sysex_msgs[x].id).indexOf(data[2])
					if(fun_id >= 0){
						const fun = sysex_msgs[Object.keys(sysex_msgs)[fun_id]].fun
						const args = data.slice(3)
						fun(...args)
					}
				}	
			});
		},
	},
	computed: {
		outputs: {
			get: function(){
				if(this.midi){
					return Array.from(this.midi.outputs.values())
				}else{
					return []
				}
			},
			set: function(){
			}
		},
		inputs: {
			get: function(){
				if(this.midi){
					return Array.from(this.midi.inputs.values())
				}else{
					return []
				}
			},
			set: function(){
			}
		},
	},
	component:{
		seq: seq,
		more:more,
		options: options
	}
})

window['app'] = app
