defmodule EDuxTest do
  use ExUnit.Case
  alias Test.CounterReducer
  alias Test.FriendsReducer

  describe "Single Reducer" do
    test "Getting State" do
      {:ok, counter} = EDux.start_link(CounterReducer)
      assert EDux.get_state(counter) == 0
    end
    
    test "Does nothing for bogus messages" do
      {:ok, store} = EDux.start_link(CounterReducer)
      EDux.dispatch(store, %{type: "TOTALLY BOGUS"})
      assert EDux.get_state(store) == 0
    end

    test "Increments state" do
      {:ok, store} = EDux.start_link(CounterReducer)
      EDux.dispatch(store, %{type: "INCREMENT"})
      assert EDux.get_state(store) == 1
    end

    test "Decrements state" do
      {:ok, store} = EDux.start_link(CounterReducer)
      EDux.dispatch(store, %{type: "DECREMENT"})
      assert EDux.get_state(store) == -1
    end

    test "notifies subscribers of changes" do
      Process.register self(), :test
      {:ok, store} = EDux.start_link(CounterReducer)
      EDux.subscribe(store, fn () -> 
        send :test, :called_callback
      end)
      EDux.dispatch(store, %{type: "DECREMENT"})
      assert_receive :called_callback
    end
  end
  describe "Multiple Reducers" do
    test "Getting State" do
      {:ok, store} = EDux.start_link(%{counter: CounterReducer, friends: FriendsReducer})
      %{counter: counterState, friends: friendsState} = EDux.get_state(store)
      assert counterState == 0
      assert friendsState == []
    end

    test "Does nothing for bogus messages" do
      {:ok, store} = EDux.start_link(%{counter: CounterReducer, friends: FriendsReducer})
      EDux.dispatch(store, %{type: "TOTALLY BOGUS"})
      %{counter: counterState, friends: friendsState} = EDux.get_state(store)
      assert counterState == 0
      assert friendsState == []
    end

    test "Changes state" do
      {:ok, store} = EDux.start_link(%{counter: CounterReducer, friends: FriendsReducer})
      EDux.dispatch(store, %{type: "INCREMENT"})
      %{counter: counterState, friends: friendsState} = EDux.get_state(store)
      assert counterState == 1
      assert friendsState == []

      EDux.dispatch(store, %{type: "ADD_FRIEND", friend: %{name: "Steven", id: "1"}})
      %{counter: counterState, friends: friendsState} = EDux.get_state(store)
      assert counterState == 1
      assert friendsState == [%{id: "1", name: "Steven"}]
    end

    test "Takes initial state properly" do
      {:ok, store} = EDux.start_link(
                      %{counter: CounterReducer, friends: FriendsReducer},
                      %{counter: 42, friends: [%{id: "42", name: "Steven"}]})
      %{counter: counterState, friends: friendsState} = EDux.get_state(store)
      assert counterState == 42
      assert friendsState == [%{id: "42", name: "Steven"}]
    end

    test "notifies subscribers of changes" do
      Process.register self(), :test
      {:ok, store} = EDux.start_link(%{counter: CounterReducer, friends: FriendsReducer})
      EDux.subscribe(store, fn () -> 
        send :test, :called_callback
      end)
      EDux.dispatch(store, %{type: "DECREMENT"})
      assert_receive :called_callback
    end
  end
end

defmodule Reducer do
  @callback reduce(any, Map :: map()) :: any
end

defmodule Test.CounterReducer do
  @behaviour Reducer
  def reduce(_, %{type: "@@EDux/INIT"}),    do: 0
  def reduce(state, %{type: "INCREMENT"}),  do: state + 1
  def reduce(state, %{type: "DECREMENT"}),  do: state - 1
  def reduce(state, _),                     do: state 
end

defmodule Test.FriendsReducer do
  @behaviour Reducer
  def reduce(_,     %{type: "@@EDux/INIT"}), do: []
  def reduce(state, %{type: "ADD_FRIEND", friend: friend}), do: state ++ [friend]
  def reduce(state, %{type: "REMOVE_FRIEND", id: id}) do 
    for i <- state, i.id != id, do: i
  end
  def reduce(state, _), do: state
end
