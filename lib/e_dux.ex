defmodule EDux do
  use GenServer


  def start_link(reducerMap, initialState \\ nil) 
  def start_link(reducerMap, initialState) when is_map(reducerMap) do
    GenServer.start_link(__MODULE__, [reducerMap, initialState])
  end

  def start_link(reducerModule, initialState) do
    GenServer.start_link(__MODULE__, [reducerModule, initialState])
  end

  def dispatch(store, action) do
    GenServer.cast(store, {:dispatch, action})
  end

  def get_state(store) do
    GenServer.call(store, {:get_state})
  end

  def subscribe(store, listener) do
    GenServer.cast(store, {:subscribe, listener})
  end

  def init([reducerMap = %{}, nil]), do: init([reducerMap, %{}])
  def init([reducerMap = %{}, initialState]) do
    reducers = Enum.reduce(reducerMap, %{}, fn ({label, reducerModule}, map) ->
    {:ok, reducer} = EDux.start_link(reducerModule, Map.get(initialState, label))
    Map.put(map, label, reducer)
    end)
    {:ok, %{combined_reducers: reducers}}
  end

  def init([reducerModule, nil]) do
    state = apply(reducerModule, :reduce, [nil, %{type: "@@EDux/INIT"}])
    {:ok, %{reducer: reducerModule, listeners: [], state: state }}
  end

  def init([reducerModule, initialState]) do
    {:ok, %{reducer: reducerModule, listeners: [], state: initialState }}
  end

  def handle_call({:get_state}, _from, %{state: state} = state_data) do
    {:reply, state, state_data}
  end

  def handle_call({:get_state}, _from, %{combined_reducers: reducers} = state_data) do
    state = Enum.reduce(reducers, %{}, fn ({label, reducer}, map) -> 
      Map.put(map, label, EDux.get_state(reducer))
    end)
    {:reply, state, state_data}
  end

  def handle_cast({:dispatch, action}, %{combined_reducers: reducers} = state_data) do
    for r <- Map.values(reducers), do: EDux.dispatch(r, action)
    {:noreply, state_data}
  end

  def handle_cast({:dispatch, action}, %{state: state, reducer: reducer, listeners: listeners} = state_data) do
    state = apply(reducer, :reduce, [state, action])
    for l <- listeners, do: l.()
    {:noreply, %{state_data | state: state}}
  end

  def handle_cast({:subscribe, listener}, %{listeners: listeners} = state_data) do
    {:noreply, %{state_data | listeners: [listener | listeners]}}
  end
end

