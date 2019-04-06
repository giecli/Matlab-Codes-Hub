desiredPower = 40000;
p1 = 25000;
T4 = 1100;
PR_c = 2;
T_amb = 200;
NucFuel = 'UO2';
RecupMatl = 'IN';
H2O = 0:5:100;
CO2 = 100 - H2O;
H2O(end) = 1;
CO2(1) = 1;
fluid = 'CO2';
mode = 2;

for i = 18%17:length(CO2)
%     fluid4file = strcat('CO2','H2O',num2str(CO2(i)),num2str(H2O(i)));
%     fluid = {'CO2','WATER',num2str(CO2(i)),num2str(H2O(i))};
%     fluidfile = strcat('C:\Users\sondelski\OneDrive - UW-Madison\nuclear project\H2O Information\Properties\',fluid4file);
%     load(fluidfile)
%     if i == length(CO2)
%         fluid = 'WATER';
%     elseif i == 1
%         fluid = 'CO2';
%     end
    
    fluid
    options1 = optimset('TolX',1e-5);
    A_panel = 26:2:40;
    for i = 1:length(A_panel)
        [ UA(1,i),m_dot(1,i) ] = minimumUA(desiredPower,p1,T4,PR_c,A_panel(i),...
            T_amb,fluid,mode);
        m_dotcycle_max = m_dot(1,i);
        for j = 1:30
            if j > 1
                UA(j,i) = UA(j-1,i)+10000/30;
            end
            [ mass_total(j,i),~,~,~,m_dot_last(j,i) ] = totalMass( UA(j,i),desiredPower,p1,T4,PR_c,A_panel(i),...
                T_amb,fluid,mode,m_dotcycle_max,options1,NucFuel,RecupMatl);
            m_dotcycle_max = m_dot_last(j,i);
            
            [~,~,~,~,~,~,~,~,...
                ~,T1(j,i),~,~,~,~,~,~,~,~,~,~,~,~,...
                ~,~,~,~,~] = BraytonCycle(m_dot_last(j,i),p1,T4,PR_c,UA(j,i),...
                A_panel(i),T_amb,fluid,mode,0);
        end
    end
    
end