set(SOURCES ControllerActivity.cpp
            ControllerState.cpp
            DefaultButtonMap.cpp
            DefaultKeyboardTranslator.cpp
            DefaultMouseTranslator.cpp
            InputSink.cpp
            PhysicalFeature.cpp
            PhysicalTopology.cpp
)

set(HEADERS ControllerActivity.h
            ControllerState.h
            DefaultButtonMap.h
            DefaultKeyboardTranslator.h
            DefaultMouseTranslator.h
            InputSink.h
            PhysicalFeature.h
            PhysicalTopology.h
)

core_add_library(games_controller_input)
