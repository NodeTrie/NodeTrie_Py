from libc.stdlib cimport malloc, free
from cpython.string cimport PyString_AsString
from cpython.version cimport PY_MAJOR_VERSION
cimport graphite_functions
cimport cnode

cdef str ENCODING='utf-8'

cdef bytes _encode_bytes(_str):
    if isinstance(_str, bytes):
        return _str
    elif PY_MAJOR_VERSION < 3 and isinstance(_str, unicode):
        return _str.encode(ENCODING)
    elif PY_MAJOR_VERSION >= 3 and isinstance(_str, str):
        return bytes(_str, ENCODING)
    return bytes(_str)

cdef unsigned char ** to_cstring_array(list list_str):
    cdef unsigned int i
    cdef unsigned char **ret = <unsigned char **>malloc((len(list_str)+1) * sizeof(unsigned char *))
    if not ret:
        raise MemoryError()
    cdef bytes _str
    for i in range(len(list_str)):
        list_str[i] = _encode_bytes(list_str[i])
        ret[i] = <unsigned char *>PyString_AsString(list_str[i])
    ret[i+1] = NULL
    return ret


cdef object PyNode_Init(cnode.Node *node):
    """Python Node object factory class for cnode.Node*"""
    cdef Node _node = Node()
    _node._node = node
    return _node


cdef class Node:
    """Node class wrapper for cnode.Node.
    Implements init, clear, insertion and is_leaf of Node definitions
    as well as tree queries with wildcard pattern
    """

    def __cinit__(self):
        self._node = NULL

    def __dealloc__(self):
        if self._node is not NULL and self._node.name is NULL:
            cnode.clear(self._node)

    property children:
        """Get node children list

        :rtype: list(:py:class:`Node`)"""
        def __get__(self):
            if self._node is NULL:
                return []
            if self._node.children_i == 0:
                return []
            cdef unsigned int i
            return [PyNode_Init(&self._node.children[i])
                    for i in range(self._node.children_i)]

    property children_size:
        """Get children list size

        :rtype: int"""
        def __get__(self):
            if self._node is not NULL:
                return self._node.children_i

    property name:
        """Get node name

        :rtype: unicode
        """
        def __get__(self):
            if self._node is not NULL and self._node.name is not NULL:
                return self._node.name.decode(ENCODING)

    # cpdef list to_array(self):
    #     """Return list of (name, children_list) items for this node's children"""
    #     cdef Node node
    #     if self._node.children_i == 0:
    #         return
    #     return [(PyString_AsString(_encode_bytes(node.name)),
    #              node.to_array(),) for node in self.children]

    # @staticmethod
    # def from_array(list dumped_ar):
    #     for child_name, child_array in dumped_ar:
    #         # print "Inserting %s to parent" % (child_name,)
    #         child = Node.from_array(child_array)
    #         # parent = child
    #     return PyNode_Init(new_root)

    def is_leaf(self):
        """Check if node is a leaf

        :rtype: bool
        """
        return self._is_leaf(self._node)

    cdef bint _is_leaf(self, cnode.Node *node):
        return cnode.is_leaf(node)

    def insert(self, path, str separator='.'):
        """Insert tree path string as nodes separated by separator

        :param path: str
        :param separator: Separator to split path on"""
        cdef list paths = path.split(separator)
        return self.insert_split_path(paths)

    cdef cnode.Node* _insert(self, unsigned char *name) nogil:
        return cnode.insert(self._node, name)

    cpdef void insert_split_path(self, list paths):
        """Insert tree paths list

        :param paths: List of paths to insert"""
        if len(paths) == 0:
            return
        cdef unsigned char **c_paths = to_cstring_array(paths)
        self._insert_split_path(c_paths)
        free(c_paths)

    cdef void _insert_split_path(self, unsigned char **paths) nogil:
        if self._node == NULL:
            self._node = cnode.init_node()
        _node = self._node
        cnode.insert_paths(self._node, paths)

    def query(self, query):
        """Return nodes matching Graphite glob pattern query"""
        cdef list nodes = sorted(self.search(self, query.split('.'), []))
        cdef Node node
        return (('.'.join(path), node,)
                for path, node in nodes)

    cdef list _get_matched_children(self, sub_query, Node node):
        if self.is_pattern(sub_query):
            return graphite_functions.match_entries(node, sub_query)
        cdef Node _node
        return [_node for _node in node.children
                if _node.name == sub_query]

    def search(self, Node node, list split_query, list split_path):
        """Return matching children for each query part in split query starting
        from given node"""
        sub_query = split_query[0]
        matched_children = self._get_matched_children(sub_query, node)
        cdef Node child_node
        cdef list child_path
        cdef list child_query
        for child_node in matched_children:
            child_path = split_path[:]
            child_path.append(child_node.name)
            child_query = split_query[1:]
            if len(child_query) > 0:
                for sub in self.search(child_node, child_query, child_path):
                    yield sub
            else:
                yield (child_path, child_node)

    cpdef is_pattern(self, pattern):
        byte_str = _encode_bytes(pattern)
        cdef char* c_pattern = byte_str
        return self._is_pattern(c_pattern)

    cdef bint _is_pattern(self, char *pattern) nogil:
        return cnode.is_pattern(pattern)
