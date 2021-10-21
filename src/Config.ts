export interface sample{
	id: number;
        name:string;
        frames: number;
}

interface sysex_msg{
        id: number;
        fun: Function;
	[name:string]:any;
}

export interface Config{
	bpm:number;
	beat_intervals:number;
        samples:sample[];
        basepath: string;
        webmidi_sysex_id: number;
        sc_sysex_id: number;
	limits:{
		[name: string]: {
			min?:number;
			max?:number;
		}
	}
        sysex_msgs: {
                [msg: string] :sysex_msg
        };
}


export const Config:Config = {
	bpm:120,
	beat_intervals: 32,
	samples: [],
	basepath : "",
	webmidi_sysex_id:111,
	sc_sysex_id: 112,
	limits:{
		rate:{
			min:-16,
			max:16
		},
		tempo:{
			max:1024
		},
		amp:{
			max:32
		}
	},
	sysex_msgs:{
		tick:{
			id: 0,
			fun: function(delta:number){
				for(let i=0;i<this.sequences.length;i++){
					this.sequences[i].beat++;
				}
			}
		},
		ping: {
			id:1,
			fun:function(){
				this.online = true
			},
		},
		loadSamples:{
			id:2,
			fun:function(sample_id:number , ...nframesArr:number[]){
				const nframes = this.retrieve_num(nframesArr)
				console.debug("nframes",nframes)
				if(this.config.samples[sample_id]){
					this.config.samples[sample_id].frames = nframes
				}
			}
		},
		schedSeq: {
			id: 3,
			fun: function(){

			}
		}
	}
}
