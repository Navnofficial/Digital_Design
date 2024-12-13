* D:\project\VLSI\AND_GATE\And_gate.asc
m1 n003 input_b 0 0 nmos
m2 n002 input_a n003 n003 nmos
m3 n001 input_a n002 n002 pmos
m4 n001 input_b n002 n002 pmos
m5 n004 n002 0 0 nmos
m6 output n002 n004 n004 nmos
m7 n001 n002 output output pmos
m8 n001 n002 output output pmos
v-a input_a 0 pulse(0 5 0 5n 5n 20m 40m)
v-b input_b 0 pulse(0 5 0 5n 5n 40m 80m)
vdd n001 0 5
.model pmos pmos
.model nmos nmos
.tran 160m
.end
