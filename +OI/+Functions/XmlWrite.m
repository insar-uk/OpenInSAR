classdef XmlWrite
    properties
        contentBuffer = 1024;
        contents = blanks(1024);
        contStruct = struct;
        contCount = 0;
        contentLength = 0;
        filepath = '';
    end

    properties (Constant = true)
        opener = @(c) [newline '<' c '>'];
        closer = @(c) [newline '</' c '>'];
        tabs = @(n) char(ones(1,n)*9);
    end

    methods
        function this = XmlWrite( structToWrite, filepathToSave )
			if nargin==0
				return;
			end

            this.contentBuffer = numel(this.contents);
            if OI.Compatibility.is_stringy( structToWrite )
                this = this.append( structToWrite );
%                 str = char(structToWrite);
%                 this.contents(1:numel(str)) = str;
            else
				this.contents = OI.Compatibility.xml_stringify( structToWrite );
                % this = this.stringify( structToWrite, 0 );
            end
            % if a filepath is given, write to it.
            if nargin == 2
                this.filepath = filepathToSave;
                this.write();
            end
        end

        function this = stringify( this, s, level )
            switch class(s)
                case 'struct'
                    fnCells = fieldnames( s );
                    % We need to do each
                    for fnC = fnCells(:)'
                        fn = fnC{1};
                        this = this.append( this.opener(fn) );
                        fieldContent = s.(fn);
                        % if its a string we're at bottom level
                        if OI.Compatibility.is_stringy(fieldContent)
                           this = this.stringify( fieldContent, level+1 );
                           this = this.append( this.closer(fn) );
                           continue
                        end
                        % if its a struct we need to take care if its
                        % scalar struct
                        for ii=1:numel(fieldContent)
                            this = this.stringify( s.(fn)(ii), level+1 );
                        end
                        this = this.append( this.closer(fn) );
                    end
                case 'string' % convert to char
                    this = this.append( char(s) );
                case 'char'
                    this = this.append( s );
                case {'double','single','int8', 'uint8','int16', ...
                        'uint16','int32','uint32','int64', 'uint64'}
                    this = this.append( num2str(s) );
                case 'logical' % convert to 1s and 0s.
                    this = this.stringify( uint8(s), level );
            end

        end

        function this = append( this, str )
            %why is strcat so slow and overengineered? Is there a c
            %alternative?
            % For now just do the cpp approach and reserve space by doubling the
			% char array when space runs out.
            if isempty(str); return; end
            range = this.contentLength+1:this.contentLength+numel(str);
            if range(end)>this.contentBuffer
                this.contentBuffer = this.contentBuffer * 2;
                blankSize = this.contentBuffer - this.contentLength;
                b = blanks(blankSize);
 %              this.contents( this.contentLength+1:this.contentBuffer ) = b;
                this.contents( this.contentBuffer ) = ' ';
            end
            this.contents(this.contentLength+1:this.contentLength+numel(str)) = str;
            this.contentLength = range(end);

            this.contents = [ this.contents, str ];
%            this.contCount = this.contCount+1;
%            this.contStruct{this.contCount} = str;
%            this.contStruct(this.contCount).str = str;
        end

        function write( this )
            % this.contents = [this.contStruct(:).str];
            f = OI.Data.TextFile( this.filepath );
            f.write( strtrim(this.contents) );
        end


    end

end

