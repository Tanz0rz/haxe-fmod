typedef Ptr<T> = cpp.Pointer<T>;

@:keep
class Cpp {

	@:generic
	@:extern
	public static inline function addr<T>( a : T ){
		return cpp.Pointer.addressOf(a);
	}
	
	@:generic
	@:extern
	public static inline function nullptr<T>() : cpp.Pointer<T> {
		return cast null;
	}
	
	
	@:generic
	@:extern
	public static inline function ref<T>( a : cpp.Pointer<T> ) {
		return cast a.ref;
	}
	
	
}