//original code by seb deepnight benard adapted for high performance computing

enum TVType {
	TLinear;
	TLoop; 			// loop : valeur initiale -> valeur finale -> valeur initiale
	TLoopEaseIn; 	// loop avec départ lent
	TLoopEaseOut; 	// loop avec fin lente
	TEase;
	TEaseIn; 		// départ lent, fin linéaire
	TEaseOut; 		// départ linéaire, fin lente
	TBurn; 			// départ rapide, milieu lent, fin rapide,
	TBurnIn; 		// départ rapide, fin lente,
	TBurnOut; 		// départ lente, fin rapide
	TZigZag; 		// une oscillation et termine sur Fin
	TRand; 			// progression chaotique de début -> fin. ATTENTION : la durée ne sera pas respectée (plus longue)
	TShake; 		// variation aléatoire de la valeur entre Début et Fin, puis s'arrête sur Début (départ rapide)
	TShakeBoth; 	// comme TShake, sauf que la valeur tremble aussi en négatif
	TJump; 			// saut de Début -> Fin
	TElasticEnd; 	// léger dépassement à la fin, puis réajustment
}

enum TVVar{
	TVVVolume;
	TVVPan;
}

@:publicFields
class TweenV {
	var man 		: SndTV;	 
	var parent		: Snd;
	var n			: Float;
	var ln			: Float;
	var speed		: Float;
	var from		: Float;
	var to			: Float;
	var type		: TVType;
	var plays		: Int; // -1 = infini, 1 et plus = nombre d'exécutions (1 par défaut)
	var varType		: TVVar; 
	var onUpdate	: Null<TweenV->Void>;
	var onEnd		: Null<TweenV->Void>;
	
	var interpolate	: Float->Float;
	
	public inline function new (
		parent:Snd	 ,
	    n:Float		 ,
	    ln:Float	 ,
		varType:TVVar,
	    speed:Float	 ,
	    from:Float	 ,
	    to:Float	 ,
	    type:TVType	 ,
	    plays		 ,
	    onUpdate	 ,
	    onEnd		 ,
	    interpolate
	) {
		this.parent			= parent		;
		this.n			    = n			 	;
		this.ln			    = ln			;
		this.varType 		= varType 		;
		this.speed		    = speed			;
		this.from		    = from			;
		this.to			    = to			;
		this.type		    = type		 	;
		this.plays		    = plays		 	;
		this.onUpdate	    = onUpdate	 	;
		this.onEnd		    = onEnd		 	;
		this.interpolate    = interpolate	;
	}
	
	public inline function reset(
		parent:Snd	 ,
	    n:Float		 ,
	    ln:Float	 ,
		varType:TVVar,
	    speed:Float	 ,
	    from:Float	 ,
	    to:Float	 ,
	    type:TVType	 ,
	    plays:Int	 ,
	    onUpdate	 ,
	    onEnd		 ,
	    interpolate
	) {
		this.parent			= parent		;
		this.n			    = n			 	;
		this.ln			    = ln			;
		this.speed		    = speed			;
		this.from		    = from			;
		this.to			    = to			;
		this.type		    = type		 	;
		this.plays		    = plays		 	;
		this.onUpdate	    = onUpdate	 	;
		this.onEnd		    = onEnd		 	;
		this.interpolate    = interpolate	;
		this.varType 		= varType 		;
	}
	
	public inline function clear(){
		parent = null;
		onEnd = null;
		onUpdate = null;
	}
	
	
	public inline
	function apply( val ) {
		switch(varType){
			case TVVVolume: parent.volume = val;
			case TVVPan: 	parent.pan = val;
		}
		
	}
	
	public inline function kill( withCbk = true ) {
		if ( withCbk )	
			man.terminateTween( this );
		else 
			man.forceTerminateTween( this) ;
	}
	
}

/**
 * tween order is not respected
 */
class SndTV {
	static var DEFAULT_DURATION = DateTools.seconds(1);
	public var fps 				= 60.0;

	var tlist					: hxd.Stack<TweenV>;
	var errorHandler			: String->Void;

	public function new() {
		tlist = new hxd.Stack<TweenV>();
		errorHandler = onError;
	}
	
	function onError(e) {
		trace(e);
	}
	
	public function count() {
		return tlist.length;
	}
	
	public function setErrorHandler(cb:String->Void) {
		errorHandler = cb;
	}
	
	public inline function create(parent:Snd, vartype:TVVar, to:Float, ?tp:TVType, ?duration_ms:Float) : TweenV{
		return create_(parent, vartype, to, tp, duration_ms);
	}
	
	public function exists(p:Snd) {
		for (t in tlist)
			if (t.parent == p )
				return true;
		return false;
	}
	
	public var pool : hxd.Stack<TweenV> = new hxd.Stack();

	function create_(p:Snd, vartype:TVVar,to:Float, ?tp:TVType, ?duration_ms:Float) : TweenV{
		if ( duration_ms==null )
			duration_ms = DEFAULT_DURATION;

		#if debug
		if ( p == null ) errorHandler("tween2 creation failed to:"+to+" tp:"+tp);
		#end
			
		if ( tp==null ) tp = TEase;

		{
			// on supprime les tweens précédents appliqués à la même variable
			for(t in tlist.backWardIterator())
				if(t.parent==p && t.varType == vartype) {
					tlist.remove(t);
					t.clear();
					pool.push(t);
				}
		}
		
		var from = switch( vartype ){
			case TVVVolume 	: p.volume;
			case TVVPan 	: p.pan;
		}
		var t : TweenV;
		if (pool.length == 0){
			t = new TweenV(
				p,
				0.0,
				0.0,
				vartype,
				1 / ( duration_ms*fps/1000 ), // une seconde
				from,
				to,
				tp,
				1,
				null,
				null,
				getInterpolateFunction(tp)
			);
		}
		else {
			t = pool.pop();
			t.reset(
				p,
				0.0,
				0.0,
				vartype,
				1 / ( duration_ms*fps/1000 ), // une seconde
				from,
				to,
				tp,
				1,
				null,
				null,
				getInterpolateFunction(tp)
			); 
			
		}

		if( t.from==t.to )
			t.ln = 1; // tweening inutile : mais on s'assure ainsi qu'un update() et un end() seront bien appelés

		t.man = this;
		tlist.push(t);

		return t;
	}

	public static inline 
	function fastPow2(n:Float):Float {
		return n*n;
	}
	
	public static inline 
	function fastPow3(n:Float):Float {
		return n*n*n;
	}

	public static inline 
	function bezier(t:Float, p0:Float, p1:Float,p2:Float, p3:Float) {
		return
			fastPow3(1-t)*p0 +
			3*( t*fastPow2(1-t)*p1 + fastPow2(t)*(1-t)*p2 ) +
			fastPow3(t)*p3;
	}
	
	// suppression du tween sans aucun appel aux callbacks onUpdate, onUpdateT et onEnd (!)
	public function killWithoutCallbacks(parent:Snd) {
		for (t in tlist.backWardIterator())
			if (t.parent==parent ){
				tlist.remove(t);
				t.clear();
				pool.push(t);
			}
	}
	
	public function terminate(parent:Snd) {
		for (t in tlist.backWardIterator())
			if (t.parent==parent){
				terminateTween(t);
				t.clear();
				pool.push(t);
			}
	}
	
	public function forceTerminateTween(t:TweenV) {
		var tOk = tlist.remove(t);
		if( tOk ){
			t.clear();
			pool.push(t);
		}
	}
	
	public function terminateTween(t:TweenV, ?fl_allowLoop=false) {
		var v = t.from+(t.to-t.from)*t.interpolate(1);
		t.apply(v);
		onUpdate(t,1);
		onEnd(t);
		if( fl_allowLoop && (t.plays==-1 || t.plays>1) ) {
			if( t.plays!=-1 )
				t.plays--;
			t.n = t.ln = 0;
		}
		else {
			tlist.remove(t);
		}
	}
	
	public function terminateAll() {
		for(t in tlist)
			t.ln = 1;
		update();
	}
	
	inline
	function onUpdate(t:TweenV, n:Float) {
		if ( t.onUpdate!=null )
			t.onUpdate(t);
	}
	
	inline
	function onEnd(t:TweenV) {
		if ( t.onEnd!=null )
			t.onEnd(t);
	}
	
	static var identityStep	= function (step) 	return step;
	static var fEase		= function (step) 	return bezier(step, 0,	0,		1,		1);
	static var fEaseIn		= function (step) 	return bezier(step, 0,	0,		0.5,	1);
	static var fEaseOut		= function (step) 	return bezier(step, 0,	0.5,	1,		1);
	static var fBurn		= function (step) 	return bezier(step, 0,	1,	 	0,		1);
	static var fBurnIn		= function (step) 	return bezier(step, 0,	1,	 	1,		1);
	static var fBurnOut		= function (step) 	return bezier(step, 0,	0,		0,		1);
	static var fZigZag		= function (step) 	return bezier(step, 0,	2.5,	-1.5,	1);
	static var fLoop		= function (step) 	return bezier(step, 0,	1.33,	1.33,	0);
	static var fLoopEaseIn	= function (step) 	return bezier(step, 0,	0,		2.25,	0);
	static var fLoopEaseOut	= function (step) 	return bezier(step, 0,	2.25,	0,		0);
	static var fShake		= function (step) 	return bezier(step, 0.5,	1.22,	1.25,	0);
	static var fShakeBoth	= function (step) 	return bezier(step, 0.5,	1.22,	1.25,	0);
	static var fJump		= function (step) 	return bezier(step, 0,	2,		2.79,	1);
	static var fElasticEnd	= function (step) 	return bezier(step, 0,	0.7,	1.5,	1);
	static var fBurn2		= function (step) 	return bezier(step, 0,	0.7,	 0.4,	1);
	
	public static inline function getInterpolateFunction(type:TVType) {
		return switch(type) {
			case TLinear		: identityStep   ;
			case TRand			: identityStep   ;
			case TEase			: fEase		     ;
			case TEaseIn		: fEaseIn		 ;
			case TEaseOut		: fEaseOut		 ;
			case TBurn			: fBurn		     ;
			case TBurnIn		: fBurnIn		 ;
			case TBurnOut		: fBurnOut		 ;
			case TZigZag		: fZigZag		 ;
			case TLoop			: fLoop		     ;
			case TLoopEaseIn	: fLoopEaseIn	 ;
			case TLoopEaseOut	: fLoopEaseOut	 ;
			case TShake			: fShake		 ;
			case TShakeBoth		: fShakeBoth	 ;
			case TJump			: fJump		     ;
			case TElasticEnd	: fElasticEnd	 ;
		}
	}
	
	public function update(?tmod = 1.0) {
		if ( tlist.length > 0 ) {
			for (t in tlist.backWardIterator() ) {
				var dist = t.to-t.from;
				if (t.type==TRand)
					t.ln+=if(Std.random(100)<33) t.speed * tmod else 0;
				else
					t.ln+=t.speed * tmod;
				t.n = t.interpolate(t.ln);
				if ( t.ln<1 ) {
					// en cours...
					var val =t.from + t.n*dist;
					
					t.apply(val);
					
					onUpdate(t, t.ln);
				}
				else // fini !
				{
					terminateTween(t, true);
					pool.push( t );
				}
			}
		}
	}
}
