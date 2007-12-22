/*  Copyright (c) 2007 Jascha Wetzel. All rights reserved
 *  License: Artistic License 2.0, see license.txt
 */
module container;

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

    int opApply(int delegate(inout T) dg)
    {
        for ( Element e=head; e !is null; e = e.next )
        {
            int ret = dg(e.value);
            if ( ret )
                return ret;
        }
        return 0;
    }

    int opApplyReverse(int delegate(inout T) dg)
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
