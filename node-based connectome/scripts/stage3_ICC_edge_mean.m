%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 3 - MEAN EDGE-LEVEL ICC PER NETWORK
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Averages ICC_struct (from stage2_FC_fingerprint.m) over the edges whose two
% nodes are in the same Yeo network (Schaefer-400, order from
% step2_parcellation_reorder.m). A network-level summary, not a per-node metric.

% Node ranges [start_node, end_node, network_id] for each of the 7 Yeo
% networks, in Schaefer-400 canonical-network order.
areas = [1 52 1; 53 143 2; 144 189 3; 190 215 4; 216 262 5; 263 339 6; 340 400 7];
networks = {'FPN', 'DMN', 'DAN', 'LN', 'VAN', 'SMN', 'VN'};
num_networks = size(areas, 1);
num_nodes = 400;

network_icc_means = struct();

for n = 1:num_networks
    start_node = areas(n, 1);
    end_node = areas(n, 2);
    network_id = areas(n, 3);
    network_name = networks{network_id};

    within_network_iccs = [];
    edge_index_vector = 1;  % index into ICC_struct, which is ordered by upper-triangle traversal below

    for j = 1:num_nodes
        for i = 1:j - 1  % upper triangle (i < j)
            if (i >= start_node && i <= end_node) && (j >= start_node && j <= end_node)
                within_network_iccs = [within_network_iccs, ICC_struct(edge_index_vector)]; 
            end
            edge_index_vector = edge_index_vector + 1;
        end
    end

    if ~isempty(within_network_iccs)
        network_icc_means.(network_name) = mean(within_network_iccs);
    else
        network_icc_means.(network_name) = NaN;
    end
end
