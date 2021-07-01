function convert_csv_to_gifti(in_tri,in_points, out_gii,io_value)
    addpath('gifti')

    tri = importdata(in_tri)
    vertices = importdata(in_points)
    

    mystruct = struct
    mystruct.faces = tri+1
    mystruct.vertices = zeros(size(vertices,1),3)
    mystruct.vertices(:,1:2) = vertices(:,:);
    
    %set third dimension according to mid, inner, outer
    mystruct.vertices(:,3) = io_value
    mystruct.vertices(:,2) = vertices(:,1)-200
    mystruct.vertices(:,1) = -vertices(:,2)
    
    g = gifti(mystruct);
    
    save(g,out_gii)
    

end



