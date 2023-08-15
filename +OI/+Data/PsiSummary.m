classdef PsiSummary < OI.Data.DataObj

properties
    id = 'PsiSummary';
    generator = 'ReferencePsi';
end%properties

methods
    function this = PsiSummary( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/$id$';
    end%ctor
end%methods

end%classdef