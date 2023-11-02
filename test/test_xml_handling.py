"""OpenInSAR uses XML files for a variety of purposes. As such a bespoke XML interface is provided. This module tests the XML interface."""
from src.openinsar_core.xml_utils import XmlObject
import pytest


def test_xml_open_file(tmp_path):
    """Test opening an XML file."""

    # Create a temporary file
    xml_file = tmp_path / "test_xml_utils.xml"
    xml_file.write_text("<root>Hello, World!</root>")

    # Open the file
    xml = XmlObject(file=xml_file)

    assert xml is not None
    assert str(xml) == "<root>Hello, World!</root>"

    # Clean up
    xml_file.unlink()


def test_xml_from_string():
    """Test creating an XML object from a string."""

    xml = XmlObject(xml_string="<root>Hello, World!</root>")

    assert xml is not None
    assert str(xml) == "<root>Hello, World!</root>"


def test_xml_from_element():
    """Test creating an XML object from a python ElementTree object."""
    import xml.etree.ElementTree as ET
    dummyElement = ET.Element('root')
    dummyElement.text = "Hello, World!"

    xml = XmlObject(xml=dummyElement)

    assert xml is not None
    assert str(xml) == "<root>Hello, World!</root>"


def test_get_node():
    """Test getting a node from an XML object."""

    xml = XmlObject(xml_string="<root><child>Hello, World!</child></root>")
    childNode = xml.find_first("child")
    assert xml is not None
    assert childNode is not None
    assert isinstance(childNode, XmlObject)
    assert childNode.tag() == "child"
    assert childNode.text() == "Hello, World!"
    assert str(childNode) == "<child>Hello, World!</child>"
    assert str(xml) == "<root><child>Hello, World!</child></root>"


def test_xml_get_attribute():
    """Test getting an attribute from an XML object."""

    xml = XmlObject(xml_string="<root><child attribute='value'>Hello, World!</child></root>")
    assert xml is not None
    childNode = xml.find_first("child")
    assert childNode is not None
    attributes = childNode.attrib()
    assert attributes is not None
    assert isinstance(attributes, dict)
    assert len(attributes) == 1
    assert attributes["attribute"] == "value"


def test_xml_find_first():
    """Find the first element with a given tag. Not proceeding elements with the same tag."""
    xml = XmlObject(xml_string="<root><child>Hello, World!</child><child>Goodbye, World!</child></root>")
    childNode = xml.find_first("child")
    assert childNode is not None
    assert childNode.text() == "Hello, World!"


def test_xml_find_all():
    """Return a list of all elements with a given tag."""
    xml = XmlObject(xml_string="<root><child>Hello, World!</child><child>Goodbye, World!</child></root>")
    childNodes = xml.find("child")
    assert childNodes is not None
    assert isinstance(childNodes, list)
    assert len(childNodes) == 2
    assert childNodes[0].text() == "Hello, World!"
    assert childNodes[1].text() == "Goodbye, World!"


class XmlToJsonTestCase:
    def __init__(self, xml_string, expected_json):
        self.xml_string = xml_string
        self.expected_json = expected_json

    def __repr__(self):
        return f"XmlToJsonTestCase(xml_string={self.xml_string}, expected_json={self.expected_json})"

    def __str__(self):
        return self.xml_string


xml_to_json_test_cases = [
    XmlToJsonTestCase(xml_string='<e/>',expected_json={'e': None}),
    XmlToJsonTestCase(
        xml_string='<e>text</e>',
        expected_json={'e': 'text'},
    ),
    XmlToJsonTestCase(
        xml_string='<e name="value" />',
        expected_json={'e': {'@name': 'value'}},

    ),
    XmlToJsonTestCase(
        xml_string='<e name="value">text</e>',
        expected_json={'e': {'@name': 'value', '#text': 'text'}},

    ),
    XmlToJsonTestCase(
        xml_string='<e> <a>text</a> <b>text</b> </e>',
        expected_json={'e': {'a': 'text', 'b': 'text'}},

    ),
    XmlToJsonTestCase(
        xml_string='<e> <a>text</a> <a>text</a> </e>',
        expected_json={'e': {'a': ['text', 'text']}},

    ),
    XmlToJsonTestCase(
        xml_string='<e> text <a>text</a> </e>',
        expected_json={'e': {'#text': 'text', 'a': 'text'}},

    ),
]


@pytest.mark.parametrize('x2j_test_case', xml_to_json_test_cases, ids=[str(x) for x in xml_to_json_test_cases])
def test_xml_to_json_converter(x2j_test_case: XmlToJsonTestCase):
    """Test converting XML to JSON. See https://www.xml.com/pub/a/2006/05/31/converting-between-xml-and-json.html"""
    xml = XmlObject(xml_string=x2j_test_case.xml_string)
    xml_as_json = xml.to_json()
    assert xml_as_json == x2j_test_case.expected_json
