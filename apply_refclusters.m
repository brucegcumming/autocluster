close all

target_probes = 1:n_probes;
force_new_clusters = false; %if you want to 

elen = cellfun(@(x) length(x),Expts);
target_blocks = find(elen > 0);

%don't apply to blocks where we dont have the FullV data
missing_Vdata = [];
for bb = target_blocks
    if Expt_name(1) == 'M'
        check_name = [data_dir sprintf('/Expt%dFullV.mat',bb)];
    else
        check_name = [data_dir sprintf('/Expt%d.p1FullV.mat',bb)];
    end
    if ~exist(check_name,'file')
       missing_Vdata = [missing_Vdata bb]; 
    end
end
target_blocks(ismember(target_blocks,missing_Vdata)) = [];

n_blocks = max(target_blocks);
n_cols = ceil(sqrt(n_blocks)); n_rows = ceil(n_blocks/n_cols);

global full_save_dir 

full_save_dir = [base_save_dir '/full'];
if ~exist(full_save_dir,'dir');
    mkdir(full_save_dir);
end


%%
% ADD CLUSTER PERMUTATION CHECKING INTO THE APPLY REF CLUSTERS FUNCTION!

fprintf('Loading RefClusters\n');
rclust_dat_name = [base_save_dir '/Ref_Clusters.mat'];
load(rclust_dat_name);

if ~exist('full_scatter_fig','var')
    full_scatter_fig = nan;
end
% if ~exist('full_dens_fig','var')
%     full_dens_fig = nan;
% end

all_clust_means = cell(n_probes,1);
all_clust_stds = cell(n_probes,1);
for bb = target_blocks
    %for LP load all Voltage signals for this block
    if Expt_name(1) == 'M'
        sfile_name = [data_dir sprintf('/Expt%dFullV.mat',bb)];
        if Vloaded ~= bb
            fprintf('Loading data file %s\n',sfile_name);
            [loadedData.V,loadedData.Vtime,loadedData.Fs] = Load_FullV(sfile_name, false, [100 nan],1:n_probes);
            Vloaded = bb;
        end
    end
    
    %load existing clusters for this block
    cur_dat_name = [base_save_dir sprintf('/Block%d_Clusters.mat',bb)];
    if exist(cur_dat_name,'file') && ~force_new_clusters
        fprintf('Loading clusters for block %d\n',bb);
        load(cur_dat_name);
    else
        fprintf('Initializing clusters for block %d\n',bb);
        Clusters = cell(n_probes,1);
    end
    
    for probe_num = target_probes
        fprintf('Applying clustering for probe %d\n',probe_num);
        if Expt_name(1) == 'G'
            loadedData = [data_dir sprintf('/Expt%d.p%dFullV.mat',bb,probe_num)];
        end
        
        %look for existing full scatter figure and open if it exists
        pfname_sc = [full_save_dir sprintf('/Probe%d_fullclust_scatter.fig',probe_num)];
        if exist(pfname_sc,'file') && ~ishandle(full_scatter_fig)
            full_scatter_fig = open(pfname_sc); set(full_scatter_fig,'visible','off');
        else
            full_scatter_fig = figure('visible','off');
        end
%         %look for existing full density figure and open if it exists
%         pfname_de = [full_save_dir sprintf('/Probe%d_fullclust_dens.fig',probe_num)];
%         if exist(pfname_de,'file') && ~ishandle(full_dens_fig)
%             full_dens_fig = open(pfname_de); set(full_dens_fig,'visible','off');
%         else
%             full_dens_fig = figure('visible','off');
%         end
        
        cur_base_block = RefClusters{probe_num}.base_block;
        if bb == cur_base_block
            [new_cluster,spike_features,spike_xy,Spikes] = apply_clustering(loadedData,RefClusters{probe_num},[],1);
        else
            [new_cluster,spike_features,spike_xy,Spikes] = apply_clustering(loadedData,RefClusters{probe_num});
        end
        
        if ~new_cluster.failed
            N_spks = size(spike_xy,1);
            spike_labels = new_cluster.spike_clusts;
            mu_inds = find(spike_labels == 1);
            out_inds = find(spike_labels == -1);
            N_sus = length(unique(spike_labels(spike_labels > 1)));
            cmap = cluster_cmap(N_sus);
            
            set(0,'CurrentFigure',full_scatter_fig);
            subplot(n_cols,n_rows,bb);hold off
            plot(spike_xy(mu_inds,1),spike_xy(mu_inds,2),'k.'); hold on
            plot(spike_xy(out_inds,1),spike_xy(out_inds,2),'r.'); 
            for ii = 1:N_sus
                plot(spike_xy(spike_labels == ii + 1,1),spike_xy(spike_labels == ii + 1,2),'.','color',cmap(ii,:));
            end
            set(gca,'xtick',[],'ytick',[]);axis tight
            for ii = 1:length(new_cluster.cluster_labels)
                h1 = plot_gaussian_2d(new_cluster.gmm_xyMeans(ii,:)',squeeze(new_cluster.gmm_xySigma(:,:,ii)),[2],'r',1);
            end
            if bb == cur_base_block
                title(['Block #',int2str(bb)],'Color','r');
            else
                title(['Block #',int2str(bb)],'Color','k');
            end
            saveas(full_scatter_fig,pfname_sc);
            close(full_scatter_fig);
            
            all_clust_means{probe_num}(bb,1) = mean(spike_xy(mu_inds,1));
            all_clust_stds{probe_num}(bb,1) = std(spike_xy(mu_inds,1));
            for ii = 1:N_sus
                all_clust_means{probe_num}(bb,ii+1) = mean(spike_xy(spike_labels==ii+1,1));
                all_clust_stds{probe_num}(bb,ii+1) = std(spike_xy(spike_labels==ii+1,1));
            end
        else
            close(full_scatter_fig);
        end
        
%         set(0,'CurrentFigure',full_dens_fig);
%         subplot(n_cols,n_rows,bb);hold on
%         [handles, details] = DensityPlot_jmm(spike_xy(:,1),spike_xy(:,2),'sqrtsc','ynormal','sd',[1 1]);
%         if bb == cur_base_block
%             dens_xrange(probe_num,:) = minmax(details.x);
%             dens_yrange(probe_num,:) = minmax(details.y);
%         end
%         set(gca,'xtick',[],'ytick',[]);
%         if bb == cur_base_block
%             title(['Block #',int2str(bb)],'Color','r');
%         else
%             title(['Block #',int2str(bb)],'Color','k');
%         end
%         saveas(full_dens_fig,pfname_de);
%         close(full_dens_fig);
        
        probe_iso_quality(bb,probe_num,:) = [new_cluster.dprime new_cluster.LL new_cluster.Lratios(1) new_cluster.iso_dists(1)];
        
        Clusters{probe_num} = new_cluster;
        
    end
    
    fprintf('Saving clusters for block %d\n',bb);
    save(cur_dat_name,'Clusters');
end

%% RESCALE SCATTER PLOTS TO HAVE CONSISTENT AXES
for probe_num = target_probes
    fprintf('Rescaling plots for probe %d\n',probe_num);
    
     %look for existing full scatter figure and open if it exists
    pfname_sc = [full_save_dir sprintf('/Probe%d_fullclust_scatter.fig',probe_num)];
    if exist(pfname_sc,'file') %&& ~ishandle(full_scatter_fig)
        full_scatter_fig = open(pfname_sc); 
    end
    
    %look for existing full scatter figure and open if it exists
    pfname_de = [full_save_dir sprintf('/Probe%d_fullclust_dens.fig',probe_num)];
    if exist(pfname_de,'file') %&& ~ishandle(full_dens_fig)
        full_dens_fig = open(pfname_de); set(full_dens_fig,'visible','on');
    end
    
    cur_base_block = RefClusters{probe_num}.base_block;
    
    set(0,'CurrentFigure',full_scatter_fig);
    subplot(n_cols,n_rows,cur_base_block);
    xl = xlim(); yl = ylim();
    for bb = target_blocks
        subplot(n_cols,n_rows,bb);
        xlim(xl); ylim(yl);
    end
    saveas(full_scatter_fig,pfname_sc);
    close(full_scatter_fig);
    
end

%% PRINT OUT PLOTS ACROSS ALL BLOCKS FOR EACH PROBE
close all
for probe_num = target_probes
    fprintf('Probe %d\n',probe_num);
    
    %look for existing full scatter figure and open if it exists
    pfname_sc = [full_save_dir sprintf('/Probe%d_fullclust_scatter.fig',probe_num)];
    if exist(pfname_sc,'file') %&& ~ishandle(full_scatter_fig)
        full_scatter_fig = open(pfname_sc); 
    end
    fillPage(full_scatter_fig,'papersize',[14 14]);
    fname = [full_save_dir sprintf('/Probe%d_fullclust_scatter',probe_num)];
    print(full_scatter_fig,fname,'-dpng');
    close(full_scatter_fig);
        
end

%% PRINT FULL DENSITY FIGURES
for probe_num = target_probes
    regenerate_allblock_xydensity(probe_num,target_blocks);
%     regenerate_allblock_xyscatters(probe_num,target_blocks);
end

%% CHECK CLUSTER ASSIGNMENTS ACROSS ALL BLOCKS FOR ALL PROBES HAVING AT LEAST 2 SUs
for probe_num = target_probes
    N_sus = max(RefClusters{probe_num}.cluster_labels) - 1;
    if N_sus > 1
        fprintf('Aligning cluster assignments across blocks for probe %d\n',probe_num);
        n_blocks = max(target_blocks);
        
        N_samps = length(RefClusters{probe_num}.params.spk_pts);
        N_chs = length(RefClusters{probe_num}.use_chs);
        ref_mean_spike = RefClusters{probe_num}.mean_spike(:,2:end);
        ms_size = size(ref_mean_spike);
        all_mean_spike = nan(n_blocks,ms_size(1),ms_size(2));
        for bb = target_blocks
            cur_data = [base_save_dir sprintf('/Block%d_Clusters.mat',bb)];
            load(cur_data,'Clusters');
            all_mean_spike(bb,:,:) = Clusters{probe_num}.mean_spike(:,2:end);
        end
        
        max_n_sus = 8;
        if N_sus > max_n_sus
            error('Too many possible SU permutations to consider!');
        end
        perm_set = perms(1:N_sus);
        n_perms = size(perm_set,1);
        block_Ctrace = nan(1,n_perms);
        best_perms = nan(1,n_blocks);
        for bb = target_blocks
            Cmat = corr(ref_mean_spike,squeeze(all_mean_spike(bb,:,:)));
            for ii = 1:n_perms
                block_Ctrace(ii) = trace(Cmat(perm_set(ii,:),:));
            end
            [~,best_perms(bb)] = max(block_Ctrace);
        end
        
        N_sus = max(RefClusters{probe_num}.cluster_labels) - 1;
        cmap = cluster_cmap(N_sus);
        n_cols = ceil(sqrt(n_blocks)); n_rows = ceil(n_blocks/n_cols);
        for bb = target_blocks
            subplot(n_cols,n_rows,bb);
            hold on
            cur_data = [base_save_dir sprintf('/Block%d_Clusters.mat',bb)];
            load(cur_data,'Clusters');
            mu_inds = Clusters{probe_num}.spike_clusts == 1;
            spike_xy = Clusters{probe_num}.spike_xy;
            plot(spike_xy(mu_inds,1),spike_xy(mu_inds,2),'k.');
            for ii = 1:N_sus
                su_inds = Clusters{probe_num}.spike_clusts == ii + 1;
                plot(spike_xy(su_inds,1),spike_xy(su_inds,2),'.','color',cmap(perm_set(best_perms(bb),ii),:));
            end
            title(sprintf('Block %d',bb));
        end
        
        resp = input('Are the new cluster assignments correct? (y/n)\n','s');
        if strcmpi(resp,'y');
            %look for existing full scatter figure and open if it exists
            pfname_sc = [full_save_dir sprintf('/Probe%d_fullclust_scatter.fig',probe_num)];
            if exist(pfname_sc,'file') %&& ~ishandle(full_scatter_fig)
                full_scatter_fig = open(pfname_sc);
            else
                full_scatter_fig = nan;
            end
            for bb = target_blocks
                fprintf('Relabeling clusters for block %d\n',bb);
                cur_data = [base_save_dir sprintf('/Block%d_Clusters.mat',bb)];
                load(cur_data,'Clusters');
                prev_labels = Clusters{probe_num}.cluster_labels;
                prev_clusts = Clusters{probe_num}.spike_clusts;
                cur_perm = perm_set(best_perms(bb),:);
                new_labels = prev_labels;
                for ii = 1:length(cur_perm)
                    new_labels(prev_labels==ii+1) = cur_perm(ii)+1;
                end
                su_spks = prev_clusts > 1;
                new_clusts = prev_clusts;
                new_clusts(su_spks) = cur_perm(prev_clusts(su_spks)-1) + 1;
                Clusters{probe_num}.spike_clusts = new_clusts;
                Clusters{probe_num}.cluster_labels = new_labels;
                Clusters{probe_num}.mean_spike(:,2:end) = Clusters{probe_num}.mean_spike(:,cur_perm+1);
                Clusters{probe_num}.std_spike(:,2:end) = Clusters{probe_num}.std_spike(:,cur_perm+1);
                Clusters{probe_num}.n_spks(2:end) = Clusters{probe_num}.n_spks(cur_perm+1);
                Clusters{probe_num}.refract = Clusters{probe_num}.refract(cur_perm,:);
                Clusters{probe_num}.Lratios = Clusters{probe_num}.Lratios(cur_perm);
                Clusters{probe_num}.iso_dists = Clusters{probe_num}.iso_dists(cur_perm);
                
                save(cur_data,'Clusters');
                
                if ishandle(full_scatter_fig)
                    subplot(n_cols,n_rows,bb);
                    hold on
                    mu_inds = Clusters{probe_num}.spike_clusts == 1;
                    spike_xy = Clusters{probe_num}.spike_xy;
                    plot(spike_xy(mu_inds,1),spike_xy(mu_inds,2),'k.');
                    hold on
                    for ii = 1:N_sus
                        su_inds = Clusters{probe_num}.spike_clusts == ii + 1;
                        plot(spike_xy(su_inds,1),spike_xy(su_inds,2),'.','color',cmap(ii,:));
                    end
                    if bb == RefClusters{probe_num}.base_block
                        title(sprintf('Block %d',bb),'Color','r');
                    else
                        title(sprintf('Block %d',bb),'Color','k');
                    end
                end
            end
            if ishandle(full_scatter_fig)
                saveas(full_scatter_fig,pfname_sc);
                close(full_scatter_fig);
            end
        end
    end
end
