function [bpod_mat] = load_bpod(mouse_id, session)

    path = "S:/fmon_data/" + num2str(mouse_id) + "/100-0/" + num2str(session) + "/";

    bpod_mat = load(path + "BpodSessionData");

end