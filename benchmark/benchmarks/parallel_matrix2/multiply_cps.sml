(*
 * native parallel matrix multiplication
 *
 * This is continuation-passing-style version.
 * This program allocates one closure for each iteration.
 *)

local

  type pthread_t = unit ptr  (* ToDo: system dependent *)

  val pthread_create =
      _import "pthread_create"
      : __attribute__((suspend))
        (pthread_t ref, unit ptr, unit ptr -> unit ptr, unit ptr) -> int
  val pthread_join =
      _import "pthread_join"
      : __attribute__((suspend))
        (pthread_t, unit ptr ref) -> int

  fun spawn f =
      let
        val r = ref _NULL
        val e = pthread_create (r, _NULL, fn _ => (f () : unit; _NULL), _NULL)
        val ref t = r
      in
        if e = 0 then t else raise Fail "spawn"
      end

  fun join th =
      (pthread_join (th, ref _NULL); ())

  val getenv = _import "getenv" : string -> unit ptr
  val atoi = _import "atoi" : unit ptr -> int
  val numThreads = getenv "NTHREADS"
  val numThreads = if numThreads = _NULL then 1 else atoi numThreads

  val DIM = 3 * 5 * 7 * 8  (* dividable by 1-8 *)
  val matrix1 = Array.array (DIM * DIM, 1.2345678)
  val matrix2 = Array.array (DIM * DIM, 1.2345678)
  val result = Array.array (DIM * DIM, 0.0)

  fun sub (a, i, j) : real =
      Array.sub (a, i * DIM + j)
  fun update (a, i, j, v : real) =
      Array.update (a, i * DIM + j, v)

  fun calc (start, last) () =
      let
        fun loop3 (i, j, k, z) =
            if k < DIM
            then loop3 (i, j, k+1, z + sub (matrix1,i,k) * sub (matrix2,k,j))
            else (update (result, i, j, z); loop2 (i, j + 1))
        and loop2 (i, j) =
            if j < DIM then loop3 (i, j, 0, 0.0) else loop1 (i + 1)
        and loop1 i =
            if i < last then loop2 (i, 0) else ()
      in
        loop1 start
      end

  fun calc_cps (start, last) () =
      let
        fun loop3 (i, j, k, z, K) =
            if k < DIM
            then loop3 (i, j, k+1, z + sub (matrix1,i,k) * sub (matrix2,k,j), K)
            else (update (result, i, j, z); K ())
        and loop2 (i, j, K) =
            if j < DIM
            then loop3 (i, j, 0, 0.0, fn _ => loop2 (i, j+1, K))
            else K ()
        and loop1 i =
            if i < last then loop2 (i, 0, fn _ => loop1 (i+1)) else ()
      in
        loop1 start
      end

  fun main () =
      let
        val d = Int.quot (DIM, numThreads)
        val m = Int.rem (DIM, numThreads)
        val widths =
            List.tabulate (numThreads, fn i => if i < m then d + 1 else d)
        fun start (w1::w2::t) = spawn (calc (w1, w1+w2)) :: start ((w1+w2)::t)
          | start _ = nil
        val threads = start widths
        val () = calc_cps (0, hd widths) ()
      in
        app join threads
      end

in

val x = main ()

end