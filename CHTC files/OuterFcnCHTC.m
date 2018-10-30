function [net_power,cyc_efficiency,D_T,D_c,Ma_T,Ma_c,Anozzle,q_reactor,...
    q_rad,T1,Power_T,Power_c,HEXeffect,energy,p1,T2,p2,T3,p3,T4,p4,T5,...
    p5,T6,p6,A_panel,Vratio] = OuterFcnCHTC(fluidfile,inputfile)
% outer file for running in CHTC
% main purpose is to unpack txt files and then run the txt file

% net_power,cyc_efficiency,D_T,D_c,Ma_T,Ma_c,Anozzle,q_reactor,...
%     q_rad,T1,Power_T,Power_c,HEXeffect,energy,p1,T2,p2,T3,p3,T4,p4,T5,...
%     p5,T6,p6,A_panel,Vratio
fluidfile
inputfile

fluid = load(fluidfile);
in = load(inputfile)

[net_power,cyc_efficiency,D_T,D_c,Ma_T,Ma_c,Anozzle,q_reactor,...
    q_rad,T1,Power_T,Power_c,HEXeffect,energy,p1,T2,p2,T3,p3,T4,p4,T5,...
    p5,T6,p6,A_panel,Vratio] = BraytonCycle(in.m_dot,in.p1,in.T4,in.PR_c,in.UA,...
    in.A_panel,in.T_amb,in.fluid,fluid.mode,in.plot)

end

