function I=normalise_image(I)

rshp = @(x) reshape(x,[],1);
I(isinf(I))=0;

M1=max(rshp(I(:,:,1)));
m1=min(rshp(I(:,:,1)));
I(:,:,1)=(I(:,:,1)-m1)./(M1-m1);

if size(I,3) > 1
    M2=max(rshp(I(:,:,2)));
    m2=min(rshp(I(:,:,2)));
    M3=max(rshp(I(:,:,3)));
    m3=min(rshp(I(:,:,3)));
    I(:,:,2)=(I(:,:,2)-m2)./(M2-m2);
    I(:,:,3)=(I(:,:,3)-m3)./(M3-m3);
end

I(isnan(I))=0;