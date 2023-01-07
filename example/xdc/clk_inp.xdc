# Copyright Till Straumann, 2023. Licensed under the EUPL-1.2 or later.
# You may obtain a copy of the license at
#   https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
# This notice must not be removed.

# Define ULPI clock for ULPI CLOCK INPUT mode

create_generated_clock -name ulpiClk -source [get_pins -hier *G_CLKDDR.U_DDR/Q] -multiply_by 1 [all_fanout -flat -endpoints_only [get_pins -hier *G_CLKDDR.U_DDR/Q]]

# we use the MMCM to create a negative phase shift to compensate
# for the routing delay from the non-CCIO pin. This works fine
# for input paths but in the opposite direction the worst
# case found by the timer is (a bit less than) 1 cycle off.
# Remedy with a multicycle path

set_multicycle_path -from [get_clocks ulpiClk] 2

