/*  Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module container;

import common;

/*******************************************************************************
    Double linked list
*******************************************************************************/
class List(T)
{
    class Element
    {
        T value;
        Element prev,
                next;

        this(T v)
        {
            value = v;
        }
    }

    Element head,
            tail;

    List opCatAssign(T v)
    {
        if ( tail is null )
            head = tail = new Element(v);
        else {
            tail.next = new Element(v);
            tail.next.prev = tail;
            tail = tail.next;
        }
        return this;
    }

    List opCatAssign(List l)
    {
        if ( l.empty )
            return this;
        if ( tail is null ) {
            head = l.head;
            tail = l.tail;
        }
        else {
            tail.next = l.head;
            tail.next.prev = tail;
            tail = l.tail;
        }
        return this;
    }

    List pushFront(T v)
    {
        if ( head is null )
            head = tail = new Element(v);
        else
        {
            head.prev = new Element(v);
            head.prev.next = head;
            head = head.prev;
        }
        return this;
    }

    List pushFront(List l)
    {
        if ( l.empty )
            return this;
        if ( head is null ) {
            head = l.head;
            tail = l.tail;
        }
        else {
            head.prev = l.tail;
            head.prev.next = head;
            head = l.head;
        }
        return this;
    }

    bool empty()
    {
        return head is null;
    }

    void clear()
    {
        head = null;
        tail = null;
    }

    void pop()
    {
        remove(tail);
    }

    void remove(Element e)
    {
        if ( e is null )
            return;
        if ( e.prev is null )
            head = e.next;
        else
            e.prev.next = e.next;
        if ( e.next is null )
            tail = e.prev;
        else
            e.next.prev = e.prev;
    }

    int opApply(int delegate(ref T) dg)
    {
        for ( Element e=head; e !is null; e = e.next )
        {
            int ret = dg(e.value);
            if ( ret )
                return ret;
        }
        return 0;
    }

    int opApplyReverse(int delegate(ref T) dg)
    {
        for ( Element e=tail; e !is null; e = e.prev )
        {
            int ret = dg(e.value);
            if ( ret )
                return ret;
        }
        return 0;
    }
}

/*******************************************************************************
    Queue based on dynamic array
*******************************************************************************/
struct Queue(T)
{
    size_t  f, b;
    T[]     queue = [T.init];

    void enqueue(T v)
    {
        queue[b] = v;
        b = (b+1)%queue.length;
        if ( b == f )
        {
            size_t l = queue.length;
            queue.length = queue.length*2;
            if ( b > 0 )
                queue[l..l+b] = queue[0..b];
            b += l;
        }
    }

    void opCatAssign(T v)
    {
        enqueue(v);
    }

    void dequeue()
    {
        assert(!empty);
        f = (f+1)%queue.length;
    }

    T front()
    {
        assert(!empty);
        return queue[f];
    }

    T[] array()
    {
        if ( f <= b )
            return queue[f..b];
        else
            return queue[f..$]~queue[0..b];
    }

    bool empty()
    {
        return f == b;
    }

    void clear()
    {
        f = b = 0;
    }
}

/*******************************************************************************
    Stack based on dynamic array
*******************************************************************************/
struct Stack(T)
{
    size_t  _top;
    T[]     stack;

    void push(T v)
    {
        if ( _top >= stack.length )
            stack.length = stack.length*2+1;
        stack[_top] = v;
        ++_top;
    }

    void opCatAssign(T v)
    {
        push(v);
    }

    void opCatAssign(T[] vs)
    {
        size_t end = _top+vs.length;
        if ( end > stack.length )
            stack.length = end*2;
        stack[_top..end] = vs;
        _top = end;
    }

    void pop(size_t num)
    {
        assert(_top>=num);
        if ( num >= _top )
            _top = 0;
        else
            _top -= num;
    }

    T pop()
    {
        assert(_top>0);
        return stack[--_top];
    }

    T top()
    {
        assert(_top>0);
        return stack[_top-1];
    }

    bool empty()
    {
        return _top == 0;
    }

    void clear()
    {
        _top = 0;
    }

    size_t length()
    {
        return _top;
    }

    T[] array()
    {
        return stack[0.._top];
    }

    T opIndex(size_t i)
    {
        return stack[i];
    }
}

/**************************************************************************************************
    Set container based on assoc array
**************************************************************************************************/
struct Set(T)
{
    bool[T] data;

    static Set opCall()
    {
        Set s;
        return s;
    }

    static Set opCall(T v)
    {
        Set s;
        s ~= v;
        return s;
    }

    void opAddAssign(T v)
    {
        data[v] = true;
    }

    void opAddAssign(Set s)
    {
        foreach ( v; s.elements )
            data[v] = true;
    }
    alias opAddAssign opCatAssign;

    size_t length()
    {
        return data.length;
    }

    T[] elements()
    {
        return data.keys;
    }

    bool remove(T v)
    {
        if ( (v in data) is null )
            return false;
        data.remove(v);
        return true;
    }

    bool contains(T v)
    {
        return (v in data) !is null;
    }

    bool contains(Set s)
    {
        Set tmp = s - *this;
        return tmp.empty;
    }

    bool empty()
    {
        return data.length==0;
    }

    Set opSub(Set s)
    {
        Set res = dup;
        foreach ( v; s.elements )
            res.remove(v);
        return res;
    }

    Set dup()
    {
        Set s;
        foreach ( v; data.keys )
            s.data[v] = true;
        return s;
    }
}

/**************************************************************************************************
    Chord of arrays
**************************************************************************************************/
struct Chord(T)
{
    size_t  top,
            len;
    T[][]   chord;

    void opCatAssign(Chord c)
    {
        size_t end = top+c.count;
        if ( end >= chord.length )
            chord.length = end*2;
        chord[top..end] = c.chord;
        top = end;
        len += c.len;
    }

    void opCatAssign(T[] a)
    {
        if ( top >= chord.length )
            chord.length = chord.length*2+1;
        chord[top] = a;
        ++top;
        len += a.length;
    }

    void prepend(T[] a)
    {
        if ( top >= chord.length )
            chord.length = chord.length*2+1;
        for ( size_t i = top; i > 0; --i )
            chord[i] = chord[i-1];
        chord[0] = a;
        ++top;
        len += a.length;
    }

    size_t count()
    {
        return chord.length;
    }

    size_t length()
    {
        return len;
    }

    T[] array()
    {
        T[] a = new T[length];
        size_t p = 0;
        foreach ( s; chord ) {
            a[p..p+s.length] = s;
            p += s.length;
        }
        return a;
    }

    static if ( is(T == char) || is(T == wchar) || is(T == dchar) )
    {
        T[] toString()
        {
            return array;
        }
    }
}

alias Chord!(char) Chordc;

/**************************************************************************************************
    AVL Tree that balances itself after each insertion
**************************************************************************************************/
class AVLTree(T, alias cmp)
{
    alias AVLNode!(T,cmp) node_t;
    node_t  root;
    bool    rebalance;

    bool insert(T v)
    {
        if ( root is null ) {
            root = new node_t(v);
            return true;
        }
        else {
            rebalance = false;
            return insert(root, v);
        }
    }
    alias insert opCatAssign;

    bool find(VT,RT)(VT v, out RT res)
    {
        static if ( !is(RT == node_t) && !is(RT == T) )
            static assert(0, "invalid result type for tree search");

        if ( root is null )
            return false;

        auto n = root;
        while ( n !is null )
        {
            if ( cmp(v, n.value) )
            {
                if ( n.left is null )
                    return false;
                n = n.left;
            }
            else if ( cmp(n.value, v) )
            {
                if ( n.right is null )
                    return false;
                n = n.right;
            }
            else
                break;
        }
        static if ( is(RT == node_t) )
            res = n;
        static if ( is(RT == T) )
            res = n.value;
        return true;
    }

    bool findLE(VT,RT)(VT v, out RT res)
    {
        static if ( !is(RT == node_t) && !is(RT == T) )
            static assert(0, "invalid result type for tree search");

        if ( root is null )
            return false;

        bool ret = false;
        auto n = root;
        while ( n !is null )
        {
            if ( cmp(v, n.value) )
            {
                if ( n.left is null )
                {
                    while ( n !is root && cmp(v, n.value) )
                        n = n.parent;
                    break;
                }
                n = n.left;
            }
            else if ( cmp(n.value, v) )
            {
                if ( n.right is null )
                    break;
                n = n.right;
            }
            else {
                ret = true;
                break;
            }
        }
        static if ( is(RT == node_t) )
            res = n;
        static if ( is(RT == T) )
            res = n.value;
        return ret;
    }

    int opApply(RT)(int delegate(ref RT v) proc)
    {
        if ( root is null )
            return 0;
        return root.traverseDepthLeft(proc);
    }

    private bool insert(node_t n, T v)
    {
        void updateParents(node_t top=null)
        {
            with ( n )
            {
                if ( top is null )
                    top = n;

                balance         = 0;
                parent.balance  = 0;

                node_t pp = parent.parent;
                if ( pp is null )
                    root = top;
                else
                {
                    if ( parent is pp.left )
                        pp.left = top;
                    else
                        pp.right = top;
                }
                parent.parent = top;
                top.parent = pp;
                if ( top !is n )
                    parent = top;
            }
        }

        with ( n )
        {
            if ( cmp(v, value) )
            {
                if ( left is null )
                {
                    left = new node_t(v, n);
                    --balance;
                    if ( balance != 0 )
                        rebalance = true;
                }
                else if ( !insert(left, v) )
                    return false;
            }
            else if ( cmp(value, v) )
            {
                if ( right is null )
                {
                    right = new node_t(v, n);
                    ++balance;
                    if ( balance != 0 )
                        rebalance = true;
                }
                else if ( !insert(right, v) )
                    return false;
            }
            else
                return false;

            if ( rebalance && parent !is null )
            {
                assert(balance != 0);
                if ( n is parent.left )
                {
                    if ( parent.balance > 0 )
                        --parent.balance;
                    else if ( parent.balance == 0 ) {
                        --parent.balance;
                        return true;
                    }
                    else
                    {
                        // single rotation to the right
                        if ( balance < 0 )
                        {
                            parent.left     = right;
                            if ( right !is null )
                                right.parent    = parent;
                            right           = parent;
                            updateParents;
                        }
                        // double rotation to the right
                        else
                        {
                            assert(right !is null);
                            node_t r            = right;
                            parent.left         = r.right;
                            if ( parent.left !is null )
                                parent.left.parent  = parent;
                            right               = r.left;
                            if ( right !is null )
                                right.parent    = n;
                            r.right             = parent;
                            r.left              = n;
                            updateParents(r);
                        }
                    }
                }
                else
                {
                    if ( parent.balance < 0 )
                        ++parent.balance;
                    else if ( parent.balance == 0 ) {
                        ++parent.balance;
                        return true;
                    }
                    else
                    {
                        // single rotation to the left
                        if ( balance > 0 )
                        {
                            parent.right    = left;
                            if ( left !is null )
                                left.parent     = parent;
                            left            = parent;
                            updateParents;
                        }
                        // double rotation to the left
                        else
                        {
                            assert(left !is null);
                            node_t l            = left;
                            parent.right        = l.left;
                            if ( parent.right !is null )
                                parent.right.parent = parent;
                            left                = l.right;
                            if ( left !is null )
                                left.parent     = n;

                            l.left              = parent;
                            l.right             = n;
                            updateParents(l);
                        }
                    }
                }
            }
            rebalance = false;
            return true;
        }
    }
}

template AVLTree(T, string cmp)
{
    bool cmpFunc(T a, T b)
    { return mixin(cmp); }

    alias AVLTree!(T,cmpFunc) AVLTree;
}

template AVLTree(T)
{
    bool cmpFunc(T1,T2)(T1 a, T2 b)
    { return a < b; }

    alias AVLTree!(T,cmpFunc) AVLTree;
}

class AVLNode(T, alias cmp)
{
    alias AVLNode!(T,cmp) node_t;
    node_t  parent, left, right;
    byte    balance;

    T       value;

    this(T v, node_t p = null)
    {
        value = v;
        parent = p;
    }

    int traverseDepthLeft(RT)(int delegate(ref RT v) proc)
    {
        int ret;
        static if ( is(RT == node_t) )
        {
            ret = proc(this);
            if ( ret )
                return ret;
        }
        static if ( is(RT == T) )
        {
            ret = proc(value);
            if ( ret )
                return ret;
        }
        static if ( !is(RT == node_t) && !is(RT == T) )
            static assert(0, "invalid result type for tree traversal");

        if ( left !is null )
        {
            ret = left.traverseDepthLeft(proc);
            if ( ret )
                return ret;
        }
        if ( right !is null )
        {
            ret = right.traverseDepthLeft(proc);
            if ( ret )
                return ret;
        }
        return 0;
    }

    bool findNext(RT)(ref RT res)
    {
        node_t n;
        if ( right is null )
        {
            for ( n = this; n.parent !is null; n = n.parent )
            {
                if ( n.parent.left is n )
                {
                    static if ( is(T : Object) )
                        assert(cmp(n.value, n.parent.value), "\n"~n.parent.value.toString~"  parent of  "~n.value.toString~"\n");
                    assert(cmp(n.value, n.parent.value));
                    n = n.parent;
                    goto Lfound;
                }
                assert(!cmp(n.value, n.parent.value));
            }
            return false;
        }
        else
        {
            assert(!cmp(right.value, value));
            n = right;
            while ( n.left !is null )
            {
                static if ( is(T : Object) )
                    assert(cmp(n.left.value, n.value), "\n"~n.left.value.toString~"\tleft of\t"~n.value.toString~"\n");
                assert(cmp(n.left.value, n.value));
                n = n.left;
            }
        }
    Lfound:
        static if ( is(RT == node_t) )
            res = n;
        static if ( is(RT == T) )
            res = n.value;
        static if ( !is(RT == node_t) && !is(RT == T) )
            static assert(0, "invalid result type for next node search");
        return true;
    }
}

unittest
{
    AVLTree!(int)  tree = new AVLTree!(int);
    for ( int i = 0; i < 100; ++i )
        tree.insert(i);

    bool checkOrder(AVLNode!(int) n)
    {
        if ( n.left !is null ) {
            assert(n.left.parent is n);
            assert(n.left.value < n.value);
        }
        if ( n.right !is null ) {
            assert(n.right.parent is n);
            assert(n.right.value >= n.value);
        }
        return true;
    }

    tree.traverseDepthLeft(&checkOrder);

    // check next
    for ( int i = 0; i < 99; ++i )
    {
        AVLNode!(int) n;
        assert(tree.find(i, n));
        assert(n.value == i);
        assert(n.findNext(n));
        assert(n.value == i+1, .toString(i+1)~" expected, "~.toString(n.value)~" found");
    }

    tree = new AVLTree!(int);
    for ( int i = 99; i >= 0; --i )
        tree.insert(i);
    tree.traverseDepthLeft(&checkOrder);

    // check next
    for ( int i = 0; i < 99; ++i )
    {
        AVLNode!(int) n;
        assert(tree.find(i, n));
        assert(n.value == i);
        assert(n.findNext(n));
        assert(n.value == i+1, .toString(i+1)~" expected, "~.toString(n.value)~" found");
    }
}
