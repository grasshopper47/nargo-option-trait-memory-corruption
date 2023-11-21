use dep::std::option::Option;

global BEGIN_ARRAY     : u8 = 0x5B; // [ left square bracket
global END_ARRAY       : u8 = 0x5D; // ] right square bracket
global BEGIN_OBJECT    : u8 = 0x7B; // { left curly bracket
global END_OBJECT      : u8 = 0x7D; // } right curly bracket
global KEY_DELIMITER   : u8 = 0x3A; // : colon
global VALUE_DELIMITER : u8 = 0x2C; // , comma
global QUOTATION_MARK  : u8 = 0x27; // ' single quote
global BACKSLASH       : u8 = 0x5C; // \ reverse solidus
global ZERO            : u8 = 0x30;

global chars = [" ","!","\"","#","$","%","&","'","(",")","*","+",",","-",".","/","0","1","2","3","4","5","6","7","8","9",":",";","<","=",">","?","@","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","[","\\","]","^","_","`","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","{","|","}","~"];

struct Property
{
    key : [u8],
    value : [u8],
}

struct Object
{
    parent : JSON,
    index : u8
}

struct JSON
{
    doc : [Property],
    children : [[Property]]
}

trait ByteArrayExtensions
{
    fn as_array(self) -> [[u8]];
    // fn as_object(self, parent: JSON) -> Option<Object>;
    fn as_object(self, parent: JSON) -> Object;

    fn print(self);
}

trait PropertyConversions
{
    fn get<N>(self, key : str<N>) -> Option<[u8]>;
    fn get_array<N>(self, key : str<N>) -> [[u8]]
    {
        let option = self.get(key);

        if (option.is_some()) { option.unwrap_unchecked().as_array() } else { [] }

        // self.get(key).unwrap_unchecked().as_array()
    }
}

impl Property
{
    unconstrained
    pub fn print(self)
    {
        dep::std::println("key");
        self.key.print();

        dep::std::println("value");
        dep::std::println("{");

        let mut object = false;
        for byte in self.value
        {
            if (object) { dep::std::println(f"        {byte}"); }
            else
            {
                let c = chars[byte-32];
                dep::std::println(f"    {c}");

                object = (byte == BEGIN_OBJECT);
            }
        }

        dep::std::println("}");
    }
}

impl Object
{
    unconstrained
    pub fn print(self) { for prop in self.parent.children[self.index] { prop.print(); } }
}

impl JSON
{
    unconstrained
    pub fn parse<N>(string : str<N>) -> JSON { JSON::parse_bytes(string.as_bytes(), 0, N, -1) }

    unconstrained
    fn parse_bytes<N>(bytes : [u8; N], begin : Field, end : Field, offset : u8) -> JSON
    {
        let mut json = JSON { doc: [], children : [] };
        let mut prop = Property { key: [], value: [] };

        let mut index : Field = begin;

        let mut value = true;
        let mut done = false;
        let mut object = false;
        let mut array = false;
        let mut string = false;

        for _ in begin..end
        {
            if (index != end)
            {
                let byte = bytes[index];
                index += 1;

                if (string)
                {
                    string = (byte != QUOTATION_MARK);

                    if      (value)  { prop.value = prop.value.push_back(byte); }
                    else if (string) { prop.key = prop.key.push_back(byte); }
                }
                else if ((byte == BEGIN_OBJECT) | (byte == BEGIN_ARRAY))
                {
                    if (byte == BEGIN_ARRAY)
                    {
                        array = true;
                        prop.value = prop.value.push_back(byte);
                    }
                    else if (object | array)
                    {
                        let mut child_objects : Field = 1;
                        let mut child_end_index : Field = 0;

                        // forward scan bytes to find the index of the matching end right curly brace }
                        for i in index..end
                        {
                            if      (child_objects != 0)   { child_objects += (((bytes[i] == BEGIN_OBJECT) as Field) - ((bytes[i] == END_OBJECT) as Field)); }
                            else if (child_end_index == 0) { child_end_index = i; }
                        }

                        let child_index : u8 = ((json.children.len() as u8) + offset + 1);
                        let child_json = JSON::parse_bytes(bytes, (index - 1), child_end_index, child_index);

                        prop.value = prop.value.push_back(BEGIN_OBJECT);
                        prop.value = prop.value.push_back(child_index);
                        prop.value = prop.value.push_back(END_OBJECT);

                        json.children = json.children.push_back(child_json.doc);
                        for child in child_json.children { json.children = json.children.push_back(child); }

                        index = child_end_index;
                    }
                    else
                    {
                        object = true;
                        value = false;
                    }
                }
                else if ((byte == END_OBJECT) | (byte == END_ARRAY))
                {
                    if (byte == END_ARRAY) { prop.value = prop.value.push_back(byte); array = false; }
                    else                   { object = false; }

                    done = !(array | (prop.value.len() == 0));
                }
                else if (byte == QUOTATION_MARK)
                {
                    string = true;
                    if (value) { prop.value = prop.value.push_back(byte); }
                }
                else if (byte == KEY_DELIMITER)
                {
                    value = true;
                    if (array) { prop.value = prop.value.push_back(byte); }
                }
                else if (byte == VALUE_DELIMITER)
                {
                    done = (!array & (prop.key.len() != 0));
                    if (array) { prop.value = prop.value.push_back(byte); }
                }
                else { prop.value = prop.value.push_back(byte); }

                if (done)
                {
                    done = false;
                    value = false;

                    json.doc = json.doc.push_back(prop);
                    prop = Property { key: [], value: [] };
                }
            }
        }

        json
    }

    unconstrained
    pub fn print(self)
    {
        for prop in self.doc { prop.print(); }

        for i in 0..self.children.len()
        {
            dep::std::println(f"-- child #{i} --");
            for prop in self.children[i] { prop.print(); }
        }
    }
}

impl ByteArrayExtensions for [u8]
{
    unconstrained
    pub fn as_array(self) -> [[u8]]
    {
        let mut result : [[u8]] = [];
        let mut value : [u8] = [];

        let size : Field = (self.len() - 1);
        let mut objects : u8 = 0;
        let mut arrays : u8 = 0;

        for i in 1..size // 1st byte is '[', last byte is ']'
        {
            let byte = self[i];

            arrays  += (((byte == BEGIN_ARRAY) as u8)  - ((byte == END_ARRAY) as u8));
            objects += (((byte == BEGIN_OBJECT) as u8) - ((byte == END_OBJECT) as u8));

            if ((byte == VALUE_DELIMITER) & (arrays == 0) & (objects == 0))
            {
                result = result.push_back(value);
                value = [];
            }
            else { value = value.push_back(byte); }
        }

        result.push_back(value)
    }

    unconstrained
    pub fn as_object(self, parent : JSON) -> Object
    {
        let result = Object { parent, index : self[1] };

        dep::std::println("as_object method object index");
        dep::std::println(result.index);
        dep::std::println("as_object method object index");

        result
    }

    // unconstrained
    // pub fn as_object(self, parent : JSON) -> Option<Object>
    // {
    //     let result = Option::some(Object { parent, index : self[1] });

    //     dep::std::println("as_object method object index");
    //     dep::std::println(result.unwrap_unchecked().index);
    //     dep::std::println("as_object method object index");

    //     result
    // }

    unconstrained
    pub fn print(self)
    {
        dep::std::println("{");
        for byte in self { let c = chars[byte-32]; dep::std::println(f"    {c}"); }
        dep::std::println("}");
    }
}

impl PropertyConversions for JSON
{
    unconstrained
    pub fn get<N>(self, key : str<N>) -> Option<[u8]>
    {
        let mut result : Option<[u8]> = Option::none();

        let key_bytes = key.as_bytes();
        for prop in self.doc
        {
            if (result.is_none())
            {
                let mut equal = (prop.key.len() == N);
                if (equal)
                {
                    for j in 0..N { equal &= (prop.key[j] == key_bytes[j]); }
                    if (equal) { result = Option::some(prop.value); }
                }
            }
        }

        result
    }

    // unconstrained
    // pub fn get_array<N>(self, key : str<N>) -> [[u8]]
    // {
    //     let option = self.get(key);

    //     if (option.is_some()) { option.unwrap_unchecked().as_array() } else { [] }
    // }
}

#[test]
unconstrained
fn convert_object_array_two_objects_with_multiple_keys()
{
    let json = JSON::parse("{'abc':[{'a':1,'b':true}]}");
    // let mut json = JSON
    // {
    //     doc : [ Property { key: "abc".as_bytes().as_slice(), value: "[{\0}]".as_bytes().as_slice() } ],
    //     children :
    //     [
    //         [
    //             Property { key: "a".as_bytes().as_slice(), value: "1".as_bytes().as_slice() },
    //             Property { key: "b".as_bytes().as_slice(), value: "true".as_bytes().as_slice() }
    //         ]
    //     ]
    // };

    // let json = JSON::parse("{'abc':[{'a':1,'b':true,'c':'123'},{'a':2,'b':false,'c':'456'}]}");
    // let mut json = JSON
    // {
    //     doc : [ Property { key: "abc".as_bytes().as_slice(), value: "[{\0},{1}]".as_bytes().as_slice() } ],
    //     children :
    //     [
    //         [
    //             Property { key: "a".as_bytes().as_slice(), value: "1".as_bytes().as_slice() },
    //             Property { key: "b".as_bytes().as_slice(), value: "true".as_bytes().as_slice() },
    //             Property { key: "c".as_bytes().as_slice(), value: "'123'".as_bytes().as_slice() },
    //         ],
    //         [
    //             Property { key: "a".as_bytes().as_slice(), value: "2".as_bytes().as_slice() },
    //             Property { key: "b".as_bytes().as_slice(), value: "false".as_bytes().as_slice() },
    //             Property { key: "c".as_bytes().as_slice(), value: "'456'".as_bytes().as_slice() },
    //         ],
    //     ]
    // };
    // json.doc[0].value[6] = 1;

    // json.print();

    let array : [[u8]] = json.get_array("abc");//.unwrap(); [{0}]

    // dep::std::println(f"array contents");

    let obj_1 = array[0].as_object(json);//.unwrap();
    dep::std::println("test method object index");
    dep::std::println(obj_1.index);
    dep::std::println("test method object index");

    obj_1.print();
}
