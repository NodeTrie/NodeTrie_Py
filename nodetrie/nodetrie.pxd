cimport cnode

cdef object PyNode_Init(cnode.Node *node)

cdef class Node:
    cdef cnode.Node *_node
    cdef bint _is_leaf(self, cnode.Node *node)
    cdef cnode.Node* _insert(self, unsigned char *name) nogil
    cpdef void insert_split_path(self, list paths)
    cdef void _insert_split_path(self, unsigned char **paths) nogil
    cdef list _get_matched_children(self, sub_query, Node node)
    cpdef is_pattern(self, pattern)
    cdef bint _is_pattern(self, char *pattern) nogil
    # cpdef list to_array(self)
