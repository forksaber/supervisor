require "mutex"
module Supervisor
  class StateStream

    alias UnsubscribeProc =  Proc(State, State, Bool)

    def initialize
      @mutex = Mutex.new
      @subscriptions = Hash(EventCallback, UnsubscribeProc).new
    end

    def publish(prev_state : State, curr_state : State)
      @mutex.synchronize do
        @subscriptions.each do |k, v|
          k.call(prev_state, curr_state)
          if v.call(prev_state, curr_state)
            @subscriptions.delete(k)
          end
        end
      end
    end

    def subscribe(callback : EventCallback, unsubscribe_proc : UnsubscribeProc)
      @mutex.synchronize { @subscriptions[callback] = unsubscribe_proc }
    end
  end
end
