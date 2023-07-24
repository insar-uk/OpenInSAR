classdef PsiSummary < OI.Data.DataObj

properties
    id = 'PSI_Summary';
    generator = 'ReferencePSI';
end%properties

methods
    function this = PsiSummary( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/$id$.mat';
    end%ctor
end%methods

end%classdef