import fnmatch

"""Graphite-API functions ported to cython from graphite-api project
http://graphite-api.readthedocs.org/
"""

def _deduplicate(list entries):
    cdef set yielded = set()
    for entry in entries:
        if entry not in yielded:
            yielded.add(entry)
            yield entry

cdef match_entries(node, pattern):
    """A drop-in replacement for fnmatch.filter that supports pattern
    variants (ie. {foo,bar}baz = foobaz or barbaz)."""
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
    matching.sort()
    return [_node for _node in ch_nodes if _node.name in matching]
