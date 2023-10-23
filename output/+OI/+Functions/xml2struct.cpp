#include "mex.h"
#include "string"
#include "vector"

// Struct to represent a node in the tree
struct TreeNode
{
    double value;                  // the value of this node
    std::string name;              // the name of this node
    struct TreeNode *parent;       // the parent node
    struct TreeNode *next_sibling; // the next sibling node
    // vector of children
    std::vector<struct TreeNode *> children;
};

// function to add a child to a node
void addChild(TreeNode *parent, TreeNode *child)
{
    // add the child to the parent's children vector
    parent->children.push_back(child);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // Check number of input arguments
    if (nrhs != 1)
        mexErrMsgTxt("One input argument is required.");

    mexPrintf("Input argument is a %s.\n", mxGetClassName(prhs[0]));

    // Check type of input argument
    if (!mxIsStruct(prhs[0]))
        mexErrMsgTxt("Input argument must be a struct array.");

    // Get the number of elements in the struct array
    int n = mxGetNumberOfElements(prhs[0]);
    mexPrintf("Number of struct elements: %d\n", n);

    // Get the number of fields in the struct array
    int nfields = mxGetNumberOfFields(prhs[0]);
    mexPrintf("Number of fields in struct: %d\n", nfields);

    std::vector<TreeNode> nodes;
    // size and populate the nodes vector
    nodes.resize(n);
    // for (int i = 0; i < n; i++)
    // {
    //     TreeNode node;
    //     nodes.push_back(node);
    // }
    // print size of nodes vector
    mexPrintf("Size of nodes vector: %d\n", nodes.size());

    double parent = mxGetScalar(mxGetField(prhs[0], 0, "parent_"));
    mexPrintf("Parent of element: %d, %f\n", 0, parent);
    mxArray *tagResult = mxGetField(prhs[0], 0, "tag_");
    // check this isn't null
    if (tagResult == NULL)
    {
        mexPrintf("tag_ is null\n");
    }
    else
    {
        mexPrintf("tag_ is not null\n");
        // print it
        std::string tag = mxArrayToString(tagResult);
        mexPrintf("tag_ is: %s\n", tag.c_str());
    }
    // // Loop over the struct array
    // for (int i = 0; i < n; i++)
    // {
    //     // Get the parent of this element
    //     double parent = mxGetScalar(mxGetField(prhs[0], i, "parent_"));
    //     std::string name = mxArrayToString(mxGetField(prhs[0], i, "name_"));

    //     mexPrintf("Parent of element %d: %f\n", i, parent);

    //     // }
    // }
}
