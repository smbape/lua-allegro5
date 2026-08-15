class Declarator {
    constructor({
        pointers,
        declarators
    }, loc) {
        this.pointers = pointers;
        this.declarators = declarators;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const pointer of this.pointers) {
            pointer.visit(cb, parents);
        }

        for (const declarator of this.declarators) {
            declarator.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.Declarator = Declarator;
