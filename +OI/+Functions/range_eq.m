function range = range_eq(sxyz, txyz)

    range = sum((sxyz-txyz).^2,2).^.5;
    
    