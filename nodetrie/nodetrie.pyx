# cython: boundscheck=False, wraparound=False, optimize.use_switch=True

# This file is part of NodeTrie.
# Copyright (C) 2017 Panos Kittenis

# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation, version 2.1.

# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

import fnmatch

from libc.stdlib cimport malloc, free
cimport cnode


ENCODING='utf-8'


cdef bytes _encode_bytes(_str):
    if isinstance(_str, bytes):
        return _str
    elif isinstance(_str, unicode):
        return _str.encode(ENCODING)
    return _str


cdef const char ** to_cstring_array(list list_str):
    cdef const char **ret
    cdef bytes _str
    cdef Py_ssize_t i
    cdef size_t l_size = len(list_str)+1
    with nogil:
        ret = <char **>malloc(
            (l_size) * sizeof(char *))
        if not ret:
            with gil:
                raise MemoryError()
    for i in range(l_size-1):
        list_str[i] = _encode_bytes(list_str[i])
        ret[i] = <char *>list_str[i]
    with nogil:
        ret[i+1] = NULL
        return ret


cdef object PyNode_Init(cnode.Node *node):
    """Python Node object factory class for cnode.Node*"""
    cdef Node _node = Node()
    _node._node = node
    return _node


# Graphite-API functions ported to cython from graphite-api project
# http://graphite-api.readthedocs.org/
def _deduplicate(list entries):
    cdef set yielded = set()
    for entry in entries:
        if entry not in yielded:
            yielded.add(entry)
            yield entry


# Graphite-API functions ported to cython from graphite-api project
# http://graphite-api.readthedocs.org/
cdef match_entries(Node node, pattern):
    """A drop-in replacement for fnmatch.filter that supports pattern
    variants (ie. {foo,bar}baz = foobaz or barbaz).

    Ported to Cython and made to use Node object instead of path"""
    cdef list ch_nodes = [_node for _node in node.children]
    cdef list node_names = [_node.name for _node in ch_nodes]
    cdef list variations
    cdef list variants
    cdef list matching
    v1, v2 = pattern.find('{'), pattern.find('}')

    if v1 > -1 and v2 > v1:
        variations = pattern[v1+1:v2].split(',')
        variants = [pattern[:v1] + v + pattern[v2+1:] for v in variations]
        matching = []

        for variant in variants:
            matching.extend(fnmatch.filter(node_names, variant))

        # remove dupes without changing order
        matching = list(_deduplicate(matching))
        return [_node for _node in ch_nodes if _node.name in matching]
    matching = fnmatch.filter(node_names, pattern)
    return [_node for _node in ch_nodes if _node.name in matching]


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

    @property
    def children(self):
        """Get node children list

        :rtype: list(:py:class:`Node`)"""
        if self._node is NULL:
            return []
        if self._node.children_i == 0:
            return []
        cdef unsigned int i
        return [PyNode_Init(&self._node.children[i])
                for i in range(self._node.children_i)]

    @property
    def children_size(self):
        """Get children list size

        :rtype: int"""
        if self._node is not NULL:
            return self._node.children_i

    @property
    def name(self):
        """Get node name

        :rtype: unicode
        """
        if self._node is not NULL and self._node.name is not NULL:
            return self._node.name.decode(ENCODING)

    def __repr__(self):
        return "Node: '{name}'".format(name=self.name)

    def is_leaf(self):
        """Check if node is a leaf

        :rtype: bool
        """
        cdef bint rc
        with nogil:
            rc = cnode.is_leaf(self._node)
        return rc

    def insert(self, path, str separator='.'):
        """Insert tree path string as nodes separated by separator

        :param path: str
        :param separator: Separator to split path on"""
        cdef list paths = path.split(separator)
        return self.insert_split_path(paths)

    cdef cnode.Node* _insert(self, const char *name) nogil:
        return cnode.insert(self._node, name)

    cpdef void insert_split_path(self, list paths):
        """Insert tree paths list

        :param paths: List of paths to insert"""
        if len(paths) == 0:
            return
        cdef const char **c_paths = to_cstring_array(paths)
        with nogil:
            self._insert_split_path(c_paths)

    cdef void _insert_split_path(self, const char **paths) nogil:
        if self._node == NULL:
            self._node = cnode.init_node()
        cnode.insert_paths(self._node, paths)
        free(paths)

    def query(self, query, separator='.'):
        """Return nodes matching Graphite glob pattern query"""
        cdef list nodes = sorted(self.search(self, query.split(separator), []))
        cdef Node node
        return ((separator.join(path), node,)
                for path, node in nodes)

    cdef list _get_matched_children(self, sub_query, Node node):
        if self.is_pattern(sub_query):
            return match_entries(node, sub_query)
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
        cdef bint rc
        byte_str = _encode_bytes(pattern)
        cdef char* c_pattern = byte_str
        with nogil:
            rc = cnode.is_pattern(c_pattern)
        return rc
