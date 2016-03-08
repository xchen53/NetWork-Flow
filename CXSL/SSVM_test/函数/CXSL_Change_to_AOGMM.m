clear


% 将我得到的跟踪结果转换为cell track challenge上的标准格式
dataset = 'training';
[ segpath trackpath ] = getpath( dataset );

fig_addr = [trackpath, '\GT\GT_after_hand_tune\'];

% 使用全局变量
global Fij Fit Fid Fiv Fmj Fsj;
global conflict_fij conflict_pair_last_xy conflict_pair_next_xy n;
% fig_dir = dir([fig_addr, '*.fig']); // 不需要用到绘制出的fig
load([fig_addr, 'GT_Flow_Variables_New.mat']);
load([trackpath, '\Pair\Pre_data_New.mat']);

frame = numel(Fmj);

%% 1、先将split和merge转换为move

for t=1:frame
    [x,ii] = find(Fmj{t});
    if isempty(x)
        continue
    end
    for i_n=1:numel(x) % 对x，ind中的每一对进行操作
        j = x(i_n); tmpii = ii(i_n);
        disp([num2str(t),'-',num2str(j), '是merge来的！']);
        source = candidate_k_last{t}{j, tmpii};
        % 给该大椭圆增加标记，说明该椭圆是2个组成的
        ss1 = Ellipse{t-1}{source(1)};
        ss2 = Ellipse{t-1}{source(2)};
        nowcount = numel(Ellipse{t});
        Ellipse{t}{nowcount+1} = ss1; Ellipse{t}{nowcount+1}.ext = 1; % 加上ext标记，说明是新加的
        Ellipse{t}{nowcount+2} = ss2; Ellipse{t}{nowcount+2}.ext = 1;
        Ellipse{t}{j}.twocells = [nowcount+1, nowcount+2];        
        % 检查出口
        tmpt = t;
        tmpj = j;
        while 1
            [ eventIn, eventOut ] = CX_CheckInOut( tmpt, tmpj );
            ev = find(eventOut);
            if isempty(ev)
                break
            end
            if ev==1 % 如果是迁移的话，需要给下一个大椭圆也加上标记
                nextind = find(Fij{tmpt}(tmpj,:));
                nexte = candidate_fij{tmpt}(tmpj, nextind);
                nowcount = numel(Ellipse{tmpt+1});
                Ellipse{tmpt+1}{nowcount+1} = ss1; Ellipse{tmpt+1}{nowcount+1}.ext = 1; % 加上ext标记，说明是新加的
                Ellipse{tmpt+1}{nowcount+2} = ss2; Ellipse{tmpt+1}{nowcount+2}.ext = 1; % 加上ext标记，说明是新加的
                Ellipse{tmpt+1}{nexte}.twocells = [nowcount+1, nowcount+2];            
                tmpt = tmpt + 1; % 更新t和tmpx
                tmpj = nexte;
            else
                break
            end
        end          
    end
end

%% 2、将6种事件放在一起，将merge和split替换为move
Final_Table = cell(frame,1); %　Final_Table 是记录各个出口的表，来源记载第三列，分裂而来为1，其余为0

for t=1:frame
    for j=1:numel(Ellipse{t})
        if isfield(Ellipse{t}{j}, 'ext') % 有ext标记，说明是新加的，无法check in out
            continue
        end
        [ eventIn, eventOut ] = CX_CheckInOut( t, j );
        % 若j的进出口都为0，说明是废置的假说，用-1进行标记
        if isequal(eventIn,zeros(1,6)) && isequal(eventOut,zeros(1,6))
            Final_Table{t}(j,1) = -1;
        end
        % ================== 检查入口 ================== %
        ev = find(eventIn);
        if ~isempty(ev)
            switch ev
                case 5 % merge而来，则修改为move
                    ind = find(Fmj{t}(j,:));
                    source = candidate_k_last{t}{j, ind};
                    s1 = Ellipse{t-1}{source(1)};
                    s2 = Ellipse{t-1}{source(2)};
                    if ~isfield(Ellipse{t}{j}, 'twocells')
                        error([num2str(t), '-', num2str(j), '是merge来的却没有twocells标记！']);
                    end
                    e1 = Ellipse{t}{Ellipse{t}{j}.twocells(1)};
                    e2 = Ellipse{t}{Ellipse{t}{j}.twocells(2)};
                    method = cal_dist(s1,s2,e1,e2);
                    if method
                        Final_Table{t-1}(source(1),1) = Ellipse{t}{j}.twocells(1);
                        Final_Table{t-1}(source(2),1) = Ellipse{t}{j}.twocells(2);
                    else
                        Final_Table{t-1}(source(2),1) = Ellipse{t}{j}.twocells(1);
                        Final_Table{t-1}(source(1),1) = Ellipse{t}{j}.twocells(2);
                    end
            end
        end
        % ================== 检查出口 ================== %
        ev = find(eventOut);
        if isempty(ev)
            continue
        end
        switch ev
            case 1 % 迁移出去，需要分2种情况
                nextind = find(Fij{t}(j,:));
                nexte = candidate_fij{t}(j, nextind);
                if isfield(Ellipse{t}{j}, 'twocells') && isfield(Ellipse{t+1}{nexte}, 'twocells') % 若2个均为大细胞
                    s1 = Ellipse{t}{Ellipse{t}{j}.twocells(1)};
                    s2 = Ellipse{t}{Ellipse{t}{j}.twocells(2)};
                    e1 = Ellipse{t+1}{Ellipse{t+1}{nexte}.twocells(1)};
                    e2 = Ellipse{t+1}{Ellipse{t+1}{nexte}.twocells(2)};
                    method = cal_dist(s1,s2,e1,e2);
                    if method
                        Final_Table{t}(Ellipse{t}{j}.twocells(1),1) = Ellipse{t+1}{nexte}.twocells(1);
                        Final_Table{t}(Ellipse{t}{j}.twocells(2),1) = Ellipse{t+1}{nexte}.twocells(2);
                    else
                        Final_Table{t}(Ellipse{t}{j}.twocells(2),1) = Ellipse{t+1}{nexte}.twocells(1);
                        Final_Table{t}(Ellipse{t}{j}.twocells(1),1) = Ellipse{t+1}{nexte}.twocells(2);
                    end
                else
                    % 若没有大细胞
                    Final_Table{t}(j,1) = nexte;
                end
            case 2 % ------ 消失 ------ %
                Final_Table{t}(j,1) = 0;
            case 3 % ------ 分裂出去 ------ %
                nextind = find(Fid{t}(j,:));
                sons = candidate_k_next{t}{j, nextind};
                Final_Table{t}(j,1) = sons(1);
                Final_Table{t}(j,2) = sons(2);
                % 要表明其子细胞来源
                Final_Table{t+1}(sons(1),3) = j;
                Final_Table{t+1}(sons(2),3) = j;
            case 4 % ------ 分离出去 ------ %
                nextind = find(Fiv{t}(j,:));
                sons = candidate_k_next{t}{j, nextind};          
                if isfield(Ellipse{t}{j}, 'twocells') % 如果自身是大细胞，则修改为迁移
                    s1 = Ellipse{t}{Ellipse{t}{j}.twocells(1)};
                    s2 = Ellipse{t}{Ellipse{t}{j}.twocells(2)};
                    e1 = Ellipse{t+1}{sons(1)};
                    e2 = Ellipse{t+1}{sons(2)};
                    method = cal_dist(s1,s2,e1,e2);
                    if method
                        Final_Table{t}(Ellipse{t}{j}.twocells(1),1) = sons(1);
                        Final_Table{t}(Ellipse{t}{j}.twocells(2),1) = sons(2);
                    else
                        Final_Table{t}(Ellipse{t}{j}.twocells(2),1) = sons(1);
                        Final_Table{t}(Ellipse{t}{j}.twocells(1),1) = sons(2);
                    end
                else % 若自身是单细胞（说明不是merge而来），则分离无效，修改为分裂
                    Final_Table{t}(j,1) = sons(1);
                    Final_Table{t}(j,2) = sons(2);
                    % 要表明其子细胞来源
                    Final_Table{t+1}(sons(1),3) = j;
                    Final_Table{t+1}(sons(2),3) = j;
                end
            case 5 % ------ merge出去 ------ %
                % 这部分放在入口处进行修改
            case 6 % ------ 新出现
                % 对出口无影响
        end
    end
end

%% 

% % 接下去的思路：先绘图，按t循环处理绘制灰度椭圆，依次给上颜色
% % 并在Ellipse中打上灰度标签，有点类似于visualize函数
% % 最后根据图来绘制有向无环图
% count = 0;
% track_txt = zeros(500,4);
% for t=1:frame
%     for j=1:numel(Ellipse{t})
%         if ~isfield(Ellipse{t}{j}, 'color') % 只对新出现的细胞做处理
%             count = count+1;
%             Ellipse{t}{j}.color = count;
%             tmpt = t;
%             tmpj = j;
%             while tmpt<frame
%                 [ eventIn, eventOut ] = CX_CheckInOut( tmpt, tmpj );
%                 % ------------------------------------------------------- %
%                 if tmpt==t % 检查原细胞的入口
%                     ev = find(eventIn);
%                     father = 0;
%                     switch ev
%                         case 1: % 迁移来的
%                             error([num2str(t), '-', num2str(j), '若是迁移来的说明跟踪中有遗漏！']);
%                         case 3: % 分裂而来，需找到母细胞
%                             [f_j, f_ii] = find(Fid{t-1});
%                             for ii=1:numel(f_j)
%                                 if any(candidate_k_next(f_j(ii), f_ii(ii))==j)
%                                     father = f_j(ii);
%                                 end
%                             end
%                             if ~father
%                                 error([num2str(t), '-', num2str(j), '是分裂而来的却找不到母细胞！']);
%                             end
%                             if ~isfield(Ellipse{t-1}{father}, 'color')
%                                 error([num2str(t-1), '-', num2str(father), '是母细胞却没有被上色！']);
%                             end
%                             father_color = Ellipse{t-1}{father}.color; % 这个用于其子细胞的最后一位
%                     end
%                 end
%                 % ------------------------------------------------------- %
%                 % 检查出口
%                 ev = find(eventOut);
%                 if t~=frame
%                     assert(numel(ev)==1)
%                 end
%                 switch ev
%                     case 1: % 如果是迁移的话，需要给下一个大椭圆也加上标记
%                         nextind = find(Fij{tmpt}(tmpj,:));
%                         nexte = candidate_fij{tmpt}(tmpj,nextind);
%                         Ellipse{t+1}{nexte}.color = count;
%                         tmpt = tmpt + 1; % 更新t和tmpx
%                         tmpj = nexte;
%                     case 2: % 最终消失
%                         track_txt(count,:) = [count, t-1, tmpt-1, father_color];
%                     case 3: % 进行分裂
%                         track_txt(count,:) = [count, t-1, tmpt-1, father_color];
%                     case 4: % 进行分离
%                     case 5: % 进行merge

%% 根据final table产生AOG
for t=1:frame
    Final_Table{t} = [Final_Table{t}, zeros(size(Final_Table{t},1),3-size(Final_Table{t},2))];
end % 将 Final_Table 统一扩展到3列
       
file = 'C:\Users\Administrator\Desktop\tracklets.txt';
delete(file);
diary(file);
diary on
disp('根据 Final_Table 生成 track_txt...');
track_txt = zeros(500,4);
count = 0;
for t=1:frame
    for j=1:size(Final_Table{t},1)  
        tmpt = t;
        tmpj = j;
        if isfield(Ellipse{t}{j}, 'color') || Final_Table{t}(j,1)== -1
            continue
        end
        fprintf('\n正在跟踪 %d:%d -> ', t,j);
        count = count+1;
        Ellipse{t}{j}.color = count; % 先上色，防止后面的重复
        % -------------------------------------------------------------- %
        while 1
            lastj = Final_Table{t}(j,3); % 此细胞的祖先
            if tmpt==frame % 达到最后一帧，进行记录
                track_txt(count,:) = [count, t-1, tmpt-1, lastj];
                fprintf('=> END ');
                break
            end
            flag = Final_Table{tmpt}(tmpj,1:2)>0;
            if isequal(flag, [1,0])
                tmpj = Final_Table{tmpt}(tmpj,1);
                tmpt = tmpt+1;
                Ellipse{tmpt}{tmpj}.color = count; % 给下一个也上色
                fprintf('%d:%d -> ', tmpt,tmpj);
            else % 除了迁移就是消失和分裂，都属于图走到了叶节点
                track_txt(count,:) = [count, t-1, tmpt-1, lastj];
                if isequal(flag, [0,0])
                    fprintf('Death');
                elseif isequal(flag, [1,1])
                    fprintf('Divide => (%d:%d, %d:%d)',...
                        tmpt+1,Final_Table{tmpt}(tmpj,1), tmpt+1,Final_Table{tmpt}(tmpj,2));
                end
                break
            end
        end
        % -------------------------------------------------------------- %
    end
end

ii = 1;
while ii<=size(track_txt,1)
    if isequal(track_txt(ii,:),[0,0,0,0])
        track_txt(ii,:) = [];
    else
        ii = ii +1;
    end
end

for h=1:size(track_txt,1)
    if track_txt(h,4)
        track_txt(h,4) = Ellipse{track_txt(h,2)}{track_txt(h,4)}.color;
    end
end
diary off             
                
            
            





