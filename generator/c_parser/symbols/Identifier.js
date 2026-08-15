class Identifier {
    constructor(name, loc) {
        this.name = name;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.Identifier = Identifier;
