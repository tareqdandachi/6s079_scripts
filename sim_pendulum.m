global tr phi_last L fr f update_counter I I_c evolve_time value_I value_I_c plot_settings

%% VARIABLES

adapt_for_video = true;

Phi02pi = 1/(2*pi);%2.07e-15 / (2*pi);
R = 1;
C = 1;
L = 2; % length of pendulum

phi_last = [0 0]; %initial phi and dphi/dt
tr = linspace(0, 10, 1000); % time range
fr = 10; % frame rate

Imin = 0;
Imax = 5;

%% DO NOT MODIFY THESE VARIABLE

I = 0; % modified by UIControl
I_c = 2.5; % modified by UIControl
update_counter = 0; % modified by ode_stack
evolve_time = 0;

plot_settings = [0.5 0.7 20];
if adapt_for_video==1
    plot_settings = [1.3 1.7 40];
end

%% UI

f = figure('Position', [10 10 1100 600]);
ax = axes('Parent',f,'position',[0.13 0.39  20 0.54]);

bgcolor = f.Color;

note = uicontrol('Parent',f,'Style','text','Position',[125,80,300,23],...
                'BackgroundColor',bgcolor,...
                'String', 'the red line in $$V(\phi)$$ represents the path the state can reach');

value_I = uicontrol('Parent',f,'Style','text','Position',[125,100,150,23],...
                'BackgroundColor',bgcolor,...
                'String', 'I = '+string(I));

value_I_c = uicontrol('Parent',f,'Style','text','Position',[275,100,150,23],...
                'BackgroundColor',bgcolor,...
                'String', 'I_c = '+string(I_c));

bl1min = uicontrol('Parent',f,'Style','text','Position',[50,0,23,23],...
                'String',string(Imin),'BackgroundColor',bgcolor);
bl1max = uicontrol('Parent',f,'Style','text','Position',[500,0,23,23],...
                'String',string(Imax),'BackgroundColor',bgcolor);
bl1 = uicontrol('Parent',f,'Style','text','Position',[240,15,100,23],...
                'String','value of I','BackgroundColor',bgcolor);

bl2min = uicontrol('Parent',f,'Style','text','Position',[50,40,23,23],...
                'String','0','BackgroundColor',bgcolor);
bl2max = uicontrol('Parent',f,'Style','text','Position',[500,40,23,23],...
                'String','5','BackgroundColor',bgcolor);
bl2 = uicontrol('Parent',f,'Style','text','Position',[240,55,100,23],...
                'String','value of I_c','BackgroundColor',bgcolor);
            
b1 = uicontrol('Parent',f,'Style','slider','Position',[81,0,419,23],...
              'value',I, 'min',Imin, 'max',Imax, 'Value', I);
            
b2 = uicontrol('Parent',f,'Style','slider','Position',[81,40,419,23],...
              'value',I_c, 'min',0, 'max',5, 'Value', I_c);
            
b1.Callback = @(es,ed) stack_ode(es.Value, Phi02pi, NaN, R, C);
            
b2.Callback = @(es,ed) stack_ode(NaN, Phi02pi, es.Value, R, C);

%% ODE SOLVER AND QUEUE

ode_update(I, Phi02pi, I_c, R, C)

function sys = stack_ode(I_update, Phi02pi, I_c_update, R, C)

    global update_counter I I_c value_I value_I_c
    
    if ~isnan(I_update)
        I = I_update;
    elseif ~isnan(I_c_update)
        I_c = I_c_update;
    end
    
    value_I.String = 'I = ' + string(I);
    value_I_c.String = 'I_c = ' + string(I_c);
    
    update_counter = update_counter + 1;
    
    t = timer('StartDelay', 0.1, 'TimerFcn', ...
                @(src,evt) ode_update(I, Phi02pi, I_c, R, C));
    
    start(t)
    
end

function  sys  = ode_update(I, Phi02pi, I_c, R, C)

    global tr phi_last L fr f update_counter evolve_time plot_settings
    
    counter = update_counter;

    [ts, phis] = ode45(@(t, phi) func_dfpen(t, phi, Phi02pi, I, I_c, R, C) ...
                        ,tr, phi_last);

    x =  L*sin(phis(:,1));
    y = -L*cos(phis(:,1));
    
    dx = max(-2, min(2, phis(:,2))).*cos(phis(:,1));
    dy = max(-2, min(2, phis(:,2))).*sin(phis(:,1));
    
    ts = ts + evolve_time; % to keep track of time when new ode's are stacked
    
    phi_slope = abs(phis(2,1) - phis(1,1));
    phi_long  = linspace(min(phis(:, 1)) - phi_slope*size(phis, 1)/2, ...
                         max(phis(:, 1)) + phi_slope*size(phis, 1)/2, ...
                         size(phis, 1)*4);
                     
    if phi_long(end) == phi_long(1) && phi_long(end) == 0  
        t_slope = ts(2) - ts(1);
        tlong   = linspace(ts(1)-t_slope*length(ts), ts(end)+t_slope*length(ts), length(ts));
        
        phi_long = tlong;
    end
    
    for id = 1:fr:length(ts)
        
        k = update_counter;

        if ~ishghandle(f) || k ~= counter
            break
        end
        
        figure(1)

        phi_last = phis(id, :);
        evolve_time = ts(id);

        % phi vs t 
        subplot(4,2,2);
        plot(ts,phis(:,1), 'LineWidth', plot_settings(1));
        line(ts(id), phis(id,1), 'Marker', '.', 'MarkerSize', ...
            plot_settings(3), 'Color', 'b');
        xlabel('time'); ylabel('\phi');

        % dphi/dt vs t
        subplot(4,2,4);
        plot(ts,phis(:,2), 'LineWidth', plot_settings(1));
        line(ts(id), phis(id,2), 'Marker', '.', 'MarkerSize', ...
            plot_settings(3), 'Color', 'b');
        xlabel('time'); ylabel('$$\dot \phi$$', 'interpreter','latex');

        % V(phi) vs phi
        Vphi = -I*phis(:,1)-I_c*cos(phis(:,1));
        Vphi_long = -I*phi_long-I_c*cos(phi_long);
        
        subplot(4,2,[6 8]);
        plot(phi_long, Vphi_long, 'LineWidth', plot_settings(2));
        line(phis(:,1), Vphi, 'color', 'r', ...
            'LineWidth', plot_settings(1));
        line(phis(id,1), Vphi(id), 'Marker', '.', ...
            'MarkerSize', plot_settings(3), 'Color', 'b');
        xlabel('\phi'); ylabel('$$V(\phi)$$', 'interpreter','latex');

        % Pendulum Animation
        subplot(4,2,[1 3 5]);
        plot([0, x(id,1);], [0, y(id,1);], ...
            '.-', 'MarkerSize', plot_settings(3), 'LineWidth', 2);
        hold on
        quiver(x(id,1),y(id,1),dx(id),dy(id),0, 'LineWidth', plot_settings(1))
        hold off
        
        axis equal; 
        axis([-2*L 2*L -2*L 2*L]);
        title(sprintf('Pendulum Analog @ Time: %0.2f', ts(id)));

        drawnow;
        
    end
    
end

%% DIFF EQ

function  dphidt  = func_dfpen(t, phi, Phi02pi, I, I_c, R, C)
    dphidt(1) = phi(2);
    dphidt(2) = (- I_c * sin(phi(1)) - Phi02pi / R * phi(2) + I) /...
                (Phi02pi * C);
    dphidt=dphidt(:);
end