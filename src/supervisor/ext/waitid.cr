lib LibC

  union SigValT
   sival_int : Int32
   sival_ptr : Void*
  end

  struct SigInfoT
    si_signo : Int
    si_errno : Int
    si_code : Int
    _align : Int
    si_pid : PidT
    si_uid : UidT
    si_value : SigValT
    si_addr : Void*
    si_status : Int
    si_band : Long
    _pad : StaticArray(Int64, 9)
  end

  enum IdTypeT
    P_ALL
    P_PID
    P_PGID
  end


  WEXITED = 4
  WNOWAIT = 0x01000000

  fun waitid(idtype : IdTypeT, id : IdT, infop : SigInfoT*, options : Int32) : Int32
end

