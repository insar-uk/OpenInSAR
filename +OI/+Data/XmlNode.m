classdef XmlNode

properties
    tag_='';
    value_='';
    attributes_='';
    index_=0;
    parent_=0;
    sibling_=0;
    child_=0;
    depth_=0;
    parentIndices=[];
end

methods
    function this = XmlNode( t, v, a, ii, p, c, s, d)
        this.tag_ = t;
        this.value_ = v;
        this.attributes_ = a;
        this.index_ = ii;
        this.parent_ = p;
        this.child_ = c;
        this.sibling_ = s;
        this.depth_ = d;
    end
    
end%methods

end%classdef
