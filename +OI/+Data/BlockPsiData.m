classdef BlockPsiData < OI.Data.DataObj
    properties
        id = 'BlockPsiData'
        generator = 'BlockPsiAnalysis'
        coherence;
        scattererPhaseOffset;
        velocity;
        displacement;
        heightError;
        amplitudeStability;
        block;
    end

    methods
        function this = BlockPsiData()
            this.filepath = '$WORK$/$id$';
            this.fileextension = 'mat';
            this.hasFile = true;
        end
    end
end
