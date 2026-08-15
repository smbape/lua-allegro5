class Pointer {
    constructor({
        pointer,
        qualifiers
    }, loc) {
        this.pointer = pointer;
        this.qualifiers = qualifiers;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.pointer.visit(cb, parents);

        for (const qualifier of this.qualifiers) {
            qualifier.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.Pointer = Pointer;
