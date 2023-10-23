#include <octave/oct.h>
#include <octave/ov-struct.h>
#include <iostream>
#include <sstream>

std::string tabs(int n){
	std::string ret = "";
	for (int i=0;i<n;i++) ret+="\t";
	return ret;
}

const std::vector<std::string> reserved_fields = { "value_", "tag_", "parent_" };

std::string field_to_text( Cell & content ){
	std::string cellContString = "";
	// Cell cells = structToParse.contents (fieldName);
	// Ignore if the field is empty
	if (content(0).numel() == 0 ) return "";

	// Convert doubles to strings
	if (content(0).class_name().compare("double") == 0){
		Matrix m = content(0).matrix_value();
		if (m.numel()) cellContString = std::to_string(m(0));
	// Append strings
	} else {
		// cells and octave char arrays are a bit trickty
		std::string cellContString =
			content(0).char_matrix_value().row_as_string(0);
		//if (cellContString.length()) ssField << cellContString;
	};
	return cellContString;
};

std::string get_field(octave_map & structToParse, std::string fieldToFind)//, std::stringstream & ss)
{
	// Get field names for a struct and find a specific one.
	// A little bit slower to loop over them all but better abstraction
	// (neater than a load of inline if statements).
	std::stringstream ssField;
	for (auto it = structToParse.begin(); it != structToParse.end(); ++it) {
		std::string fieldName = it->first;
		// If we have the right field get the content
		if (fieldName.compare(fieldToFind) == 0) {
			ssField << field_to_text( structToParse.contents (fieldName) );
		}//fieldname
	};//elements of struct array
	return ssField.str();
};


std::string get_field(octave_map & structToParse)//, std::stringstream & ss)
{
	// Get field contents regardless of name
	std::stringstream ssField;
	for (auto it = structToParse.begin(); it != structToParse.end(); ++it) {
			ssField << field_to_text( structToParse.contents (fieldName) );
	};//elements of struct array
	return ssField.str();
};

void struct_crawler
(
	octave_map structToParse,
	std::stringstream & ss,
	int level = 0
)
{
	// Recursive. Print content from xml struct arg1 into stringstream arg2.

	// struct(1..n).field(1..n).mixedTypeContent(1..n).structAgain(1..n)
	// For each field in the structure
	for (auto it = structToParse.begin(); it != structToParse.end(); ++it) {
		// Get the name and content
		std::string fieldName = it->first;
		Cell fieldContentCell = structToParse.contents(fieldName);

		// Loop over the content of the field in case of multiple elements
		int nFCC = fieldContentCell.numel();
		for (int iFCC = 0; iFCC < nFCC; iFCC++){
			octave_value contentElement = fieldContentCell(iFCC);
			// If element is another struct, recursively apply this function.
			if (contentElement.isstruct()) {
				octave_map asMap = contentElement.map_value();
				// For each structure within our structure element.
				for (int sArrInd = 0;sArrInd<asMap.length();sArrInd++){

					std::string attributes =
						get_field( asMap(sArrInd),"attributes_");
					ss << tabs(level) << '<' << fieldName;
					if (attributes.length()) ss << " " << attributes << " ";
					ss << ">\n";

					std::string value = get_field( asMap(sArrInd) ,"value_");
					if (value.length()) ss << tabs(level+1) <<  value << "\n";

					struct_crawler( asMap(sArrInd) , ss, level+1);
					ss << tabs(level) << "</" << fieldName<< ">\n";
				};
			} else {
				ss << get_field( contentElement );
			}
		};
	};
};

DEFUN_DLD
(
	OI_Xml_to_text,
	args,
	,
	"OI_Xml_to_text"
	"Take a struct from OI_Xml.to_struct and stringify it.\n"
	" (char[]) xmlText = OI_Xml_to_text( (struc) OI_Xml(x).to_struc() )"
)
{

	if (args.length () != 1)
		print_usage ();

	if (! args(0).isstruct ())
		error ("structdemo: ARG1 must be a struct");
	// Tell cpp our input is a struct
	octave_map inputStructInterface = args(0).map_value();
	// Use a stringstream to build up our text content
	std::stringstream ss;
	// Use this algo to recursively build the fields into text.
	struct_crawler( inputStructInterface, ss);
	return octave_value (ss.str());
}
