"""
Utilities for working with XML files.

OpenInSAR uses XML files for a variety of purposes. As such this bespoke XML interface is useful.
In general, however, :class:`XmlObject` is basically a wrapper around the ElementTree library.

"""

import xml.etree.ElementTree as ET
from typing import Self


class XmlObject:
    """
    A class that represents an XML object and provides methods to manipulate it.

    While this mainly uses the ElementTree library, this class allows us to adapt much more efficiently if something should change in that library.

    Attributes:
    - file: str | None: The path to the XML file to be parsed.
    - xml_string: str | None: The XML string to be parsed.
    - xml: ET.Element: The XML object to be used directly.
    """
    def __init__(self,
                 file: str | None = None,
                 xml_string: str | None = None,
                 xml: ET.Element = ET.Element('root')):
        """
        Initializes an XmlObject instance.

        self._xml stores the actual XML object in memory, currently using the ElementTree library

        Args:
        - file: str | None: The path to the XML file to be parsed.
        - xml_string: str | None: The XML string to be parsed.
        - xml: ET.Element: The XML object to be used directly.

        Raises:
        - ValueError: If no XML source is provided.
        """

        self._xml: ET.Element
        if file is not None:
            self._xml = ET.parse(file).getroot()
        elif xml_string is not None:
            self._xml = ET.fromstring(xml_string)
        elif xml is not None:
            self._xml = xml
        else:
            raise ValueError("No XML source provided")
        assert self._xml is not None

    def __getattr__(self, name) -> str | None:
        """
        Gets the text of the child element with the given name.

        Args:
        - name: str: The name of the child element.

        Returns:
        - str | None: The text of the child element, or None if it does not exist.
        """
        element = self._xml.find(name)
        return element.text if element is not None else None

    def __str__(self) -> str:
        """
        Returns the entire XML document as a string.

        Returns:
        - str: The entire XML document as a string.
        """
        return ET.tostring(self._xml, encoding='unicode')

    def __repr__(self) -> str:
        """
        Returns a string representation of the XmlObject instance.

        Returns:
        - str: A string representation of the XmlObject instance.
        """
        return f"XmlObject({self.__str__()})"

    def tag(self) -> str:
        """
        Returns the tag of the root element.

        Returns:
        - str: The tag of the root element.
        """
        return self._xml.tag

    def text(self) -> str | None:
        """
        Returns the text of the root element.

        Returns:
        - str | None: The text of the root element, or None if it does not exist.
        """
        return self._xml.text

    def attrib(self) -> dict:
        """
        Returns the attributes of the root element.

        Returns:
        - dict: The attributes of the root element.
        """
        return self._xml.attrib

    def children(self) -> list[Self]:
        """
        Returns a list of XmlObject instances representing the children of the root element.

        Returns:
        - list[Self]: A list of XmlObject instances representing the children of the root element.
        """
        return [XmlObject(xml=child) for child in self._xml]

    def find_first(self, name: str) -> Self | None:
        """
        Finds the first child element with the given name.

        Args:
        - name: str: The name of the child element.

        Returns:
        - Self | None: An XmlObject instance representing the child element, or None if it does not exist.
        """
        element = self._xml.find(name)
        return XmlObject(xml=element) if element is not None else None

    def find(self, name: str) -> list[Self]:
        """
        Finds all child elements with the given name.

        Args:
        - name: str: The name of the child elements.

        Returns:
        - list[Self]: A list of XmlObject instances representing the child elements.
        """

        elements = self._xml.findall(name)
        return [XmlObject(xml=element) for element in elements]

    def to_json(self) -> dict:
        """
        Converts the XML object to a JSON object.

        Returns:
        - dict: The JSON object representing the XML object.
        """

        def element_to_json(element: ET.Element) -> dict | list[dict] | str | None:
            """Convert an XML element to a JSON object."""
            is_leaf = len(element) == 0
            has_text = element.text and element.text.strip() != ""
            has_attributes = element.attrib

            # Leaf node
            if is_leaf and not (has_attributes or has_text):  # Empty leaf node
                return None
            elif is_leaf and has_attributes and not has_text:  # Leaf node with attributes
                return {f"@{k}": v for k, v in element.attrib.items()}
            elif is_leaf and not has_attributes and has_text:  # Leaf node with text
                assert element.text is not None  # Bad type checker, has_text
                return element.text.strip()
            elif is_leaf and has_attributes and has_text:  # Leaf node with attributes and text
                assert element.text is not None  # Bad type checker, has_text
                json_leaf = {f"@{k}": v for k, v in element.attrib.items()}
                json_leaf["#text"] = element.text.strip()
                return json_leaf

            # Non-leaf node
            has_multiple_children = len(element) > 1
            if has_multiple_children:
                result = {}
                for child in element:
                    child_result = element_to_json(child)
                    if child.tag not in result:
                        result[child.tag] = child_result
                    else:
                        if not isinstance(result[child.tag], list):
                            result[child.tag] = [result[child.tag]]
                        result[child.tag].append(child_result)
                if element.text and element.text.strip():
                    result["#text"] = element.text.strip()
                return result

            # Single child node
            child = element[0]
            child_result = element_to_json(child)
            if element.text and element.text.strip():
                # need to check if child_result is a dict or a str
                if isinstance(child_result, dict):
                    child_result["#text"] = element.text.strip()
                elif isinstance(child_result, str):
                    child_result = {"#text": element.text.strip(), child.tag: child_result}
                else:
                    raise ValueError(f"Unexpected type for child_result: {type(child_result)}")
            return child_result

        result = {self._xml.tag: element_to_json(self._xml)}
        return result


if __name__ == "__main__":
    xml = XmlObject(xml_string="<root><child>Hello, World!</child><child>Goodbye, World!</child></root>")
    print(xml.to_json())
